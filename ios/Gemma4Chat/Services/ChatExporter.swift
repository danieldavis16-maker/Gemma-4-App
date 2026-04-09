import Foundation
import UIKit

class ChatExporter {

    static func exportAsText(conversation: Conversation) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        var text = "Gemma Chat: \(conversation.title)\n"
        text += "Date: \(dateFormatter.string(from: conversation.createdAt))\n"
        text += String(repeating: "=", count: 50) + "\n\n"

        for message in conversation.messages {
            let role = message.role == .user ? "You" : message.role == .assistant ? "Gemma" : "System"
            let time = dateFormatter.string(from: message.timestamp)
            text += "[\(role)] (\(time))\n"
            text += message.content + "\n\n"
        }

        return text
    }

    static func exportAsPDF(conversation: Conversation) -> Data {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 50
        let contentWidth = pageWidth - margin * 2

        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        let data = pdfRenderer.pdfData { context in
            var yOffset: CGFloat = 0

            func startNewPage() {
                context.beginPage()
                yOffset = margin
            }

            func checkPageBreak(height: CGFloat) {
                if yOffset + height > pageHeight - margin {
                    startNewPage()
                }
            }

            startNewPage()

            // Title
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 20),
                .foregroundColor: UIColor.black
            ]
            let title = conversation.title as NSString
            let titleRect = CGRect(x: margin, y: yOffset, width: contentWidth, height: 30)
            title.draw(in: titleRect, withAttributes: titleAttrs)
            yOffset += 35

            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short

            let dateAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.gray
            ]
            let date = dateFormatter.string(from: conversation.createdAt) as NSString
            date.draw(at: CGPoint(x: margin, y: yOffset), withAttributes: dateAttrs)
            yOffset += 25

            // Messages
            for message in conversation.messages {
                let role = message.role == .user ? "You" : message.role == .assistant ? "Gemma" : "System"
                let roleColor: UIColor = message.role == .user ? .systemBlue : message.role == .assistant ? .darkGray : .orange

                let headerAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 13),
                    .foregroundColor: roleColor
                ]
                let bodyAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12),
                    .foregroundColor: UIColor.black
                ]

                let header = role as NSString
                let body = message.content as NSString

                let bodySize = body.boundingRect(
                    with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: bodyAttrs,
                    context: nil
                )

                checkPageBreak(height: bodySize.height + 30)

                header.draw(at: CGPoint(x: margin, y: yOffset), withAttributes: headerAttrs)
                yOffset += 18

                body.draw(in: CGRect(x: margin, y: yOffset, width: contentWidth, height: bodySize.height + 5), withAttributes: bodyAttrs)
                yOffset += bodySize.height + 15
            }
        }

        return data
    }

    static func share(items: [Any], from viewController: UIViewController? = nil) {
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let vc = viewController ?? UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows.first?.rootViewController {
            vc.present(activityVC, animated: true)
        }
    }
}
