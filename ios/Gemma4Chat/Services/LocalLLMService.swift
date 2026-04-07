import Foundation
import llama

enum LLMError: Error, LocalizedError {
    case failedToLoadModel
    case failedToCreateContext

    var errorDescription: String? {
        switch self {
        case .failedToLoadModel: return "Failed to load the model file"
        case .failedToCreateContext: return "Failed to create inference context"
        }
    }
}

class LocalLLMService {
    private var model: OpaquePointer?
    private var context: OpaquePointer?

    var isLoaded: Bool { model != nil && context != nil }

    init() {
        llama_backend_init()
    }

    deinit {
        unload()
        llama_backend_free()
    }

    func load(path: String) throws {
        unload()

        var mparams = llama_model_default_params()
        mparams.n_gpu_layers = 0 // Use CPU only for compatibility

        guard let m = llama_model_load_from_file(path, mparams) else {
            throw LLMError.failedToLoadModel
        }
        model = m

        var cparams = llama_context_default_params()
        cparams.n_ctx = 2048
        cparams.n_batch = 512
        cparams.n_ubatch = 512
        cparams.n_threads = Int32(min(4, ProcessInfo.processInfo.activeProcessorCount))
        cparams.n_threads_batch = cparams.n_threads
        cparams.flash_attn = false

        guard let c = llama_init_from_model(m, cparams) else {
            llama_model_free(m)
            model = nil
            throw LLMError.failedToCreateContext
        }
        context = c
    }

    func unload() {
        if let c = context { llama_free(c) }
        if let m = model { llama_model_free(m) }
        context = nil
        model = nil
    }

    func generate(prompt: String, settings: LLMSettings = .default) -> AsyncStream<String> {
        AsyncStream { [weak self] continuation in
            let task = Task.detached(priority: .userInitiated) {
                defer { continuation.finish() }
                guard let self, let model = self.model, let ctx = self.context else { return }

                let vocab = llama_model_get_vocab(model)
                guard let vocab else { return }

                // Clear KV cache
                let memory = llama_get_memory(ctx)
                llama_memory_clear(memory, true)

                // Tokenize prompt
                var tokens = self.tokenize(vocab: vocab, text: prompt, addBOS: true)
                guard !tokens.isEmpty else { return }

                // Truncate to fit context window (leave room for generation)
                let maxPromptTokens = 1536
                if tokens.count > maxPromptTokens {
                    tokens = Array(tokens.suffix(maxPromptTokens))
                }

                // Decode prompt in batches of 512
                let batchSize = 512
                var i = 0
                while i < tokens.count {
                    let end = min(i + batchSize, tokens.count)
                    var slice = Array(tokens[i..<end])
                    var batch = llama_batch_get_one(&slice, Int32(slice.count))
                    let decodeResult = llama_decode(ctx, batch)
                    guard decodeResult == 0 else {
                        continuation.yield("[Error: prompt decode failed at batch \(i/batchSize)]")
                        return
                    }
                    i = end
                }

                // Init sampler chain with configurable settings
                let sparams = llama_sampler_chain_default_params()
                guard let sampler = llama_sampler_chain_init(sparams) else { return }
                defer { llama_sampler_free(sampler) }

                llama_sampler_chain_add(sampler, llama_sampler_init_temp(settings.temperature))
                llama_sampler_chain_add(sampler, llama_sampler_init_top_k(settings.topK))
                llama_sampler_chain_add(sampler, llama_sampler_init_top_p(settings.topP, 1))
                llama_sampler_chain_add(sampler, llama_sampler_init_dist(UInt32.random(in: 0...UInt32.max)))

                var utf8Buffer = Data()

                for _ in 0..<settings.maxTokens {
                    if Task.isCancelled { break }

                    let token = llama_sampler_sample(sampler, ctx, -1)

                    if llama_vocab_is_eog(vocab, token) { break }

                    let piece = self.tokenToPiece(vocab: vocab, token: token, buffer: &utf8Buffer)
                    if !piece.isEmpty {
                        continuation.yield(piece)
                    }

                    var tokenArr = [token]
                    batch = llama_batch_get_one(&tokenArr, 1)
                    guard llama_decode(ctx, batch) == 0 else { break }
                }

                // Flush remaining UTF-8 buffer
                if !utf8Buffer.isEmpty, let str = String(data: utf8Buffer, encoding: .utf8) {
                    continuation.yield(str)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - Chat template

    static func formatChat(messages: [(role: String, content: String)], systemPrompt: String? = nil) -> String {
        var prompt = ""

        if let sys = systemPrompt, !sys.isEmpty {
            prompt += "<start_of_turn>user\n[System: \(sys)]<end_of_turn>\n"
        }

        for msg in messages {
            switch msg.role {
            case "user":
                prompt += "<start_of_turn>user\n\(msg.content)<end_of_turn>\n"
            case "assistant":
                prompt += "<start_of_turn>model\n\(msg.content)<end_of_turn>\n"
            default:
                break
            }
        }

        prompt += "<start_of_turn>model\n"
        return prompt
    }

    // MARK: - Private

    private func tokenize(vocab: OpaquePointer, text: String, addBOS: Bool) -> [llama_token] {
        let maxTokens = Int32(text.utf8.count) + (addBOS ? 1 : 0) + 1
        var tokens = [llama_token](repeating: 0, count: Int(maxTokens))
        let n = llama_tokenize(vocab, text, Int32(text.utf8.count), &tokens, maxTokens, addBOS, true)
        guard n > 0 else { return [] }
        return Array(tokens.prefix(Int(n)))
    }

    private func tokenToPiece(vocab: OpaquePointer, token: llama_token, buffer: inout Data) -> String {
        var buf = [CChar](repeating: 0, count: 64)
        var n = llama_token_to_piece(vocab, token, &buf, 64, 0, false)
        if n < 0 {
            buf = [CChar](repeating: 0, count: Int(-n) + 1)
            n = llama_token_to_piece(vocab, token, &buf, Int32(buf.count), 0, false)
        }
        guard n > 0 else { return "" }

        let bytes = buf.prefix(Int(n)).map { UInt8(bitPattern: $0) }
        buffer.append(contentsOf: bytes)

        if let str = String(data: buffer, encoding: .utf8) {
            buffer.removeAll()
            return str
        }

        // Incomplete UTF-8 sequence, wait for more bytes
        return ""
    }
}
