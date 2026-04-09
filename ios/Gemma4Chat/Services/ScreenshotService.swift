import UIKit
import SwiftUI

class ScreenshotService {

    static func renderMessage(_ message: ChatMessage) -> UIImage {
        let width: CGFloat = 375
        let padding: CGFloat = 20
        let contentWidth = width - padding * 2

        let role = message.role == .user ? "You" : "Gemma"
        let roleColor: UIColor = message.role == .user ? .systemBlue : .systemGray
        let bgColor: UIColor = message.role == .user ? .systemBlue : UIColor.systemGray5

        let roleFont = UIFont.boldSystemFont(ofSize: 13)
        let contentFont = UIFont.systemFont(ofSize: 15)

        let contentSize = (message.content as NSString).boundingRect(
            with: CGSize(width: contentWidth - 24, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin],
            attributes: [.font: contentFont],
            context: nil
        )

        let bubbleHeight = contentSize.height + 60
        let totalHeight = bubbleHeight + 80

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: totalHeight))
        return renderer.image { context in
            // Background
            UIColor.systemBackground.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: totalHeight))

            // App branding
            let brandAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 11),
                .foregroundColor: UIColor.secondaryLabel
            ]
            ("Gemma 4 Chat" as NSString).draw(at: CGPoint(x: padding, y: 12), withAttributes: brandAttrs)

            // Bubble
            let bubbleY: CGFloat = 36
            let bubbleRect = CGRect(x: padding, y: bubbleY, width: contentWidth, height: bubbleHeight)
            let path = UIBezierPath(roundedRect: bubbleRect, cornerRadius: 16)
            bgColor.setFill()
            path.fill()

            // Role
            let roleAttrs: [NSAttributedString.Key: Any] = [
                .font: roleFont,
                .foregroundColor: message.role == .user ? UIColor.white : roleColor
            ]
            (role as NSString).draw(at: CGPoint(x: padding + 12, y: bubbleY + 10), withAttributes: roleAttrs)

            // Content
            let contentAttrs: [NSAttributedString.Key: Any] = [
                .font: contentFont,
                .foregroundColor: message.role == .user ? UIColor.white : UIColor.label
            ]
            (message.content as NSString).draw(
                in: CGRect(x: padding + 12, y: bubbleY + 30, width: contentWidth - 24, height: contentSize.height + 10),
                withAttributes: contentAttrs
            )
        }
    }

    static func renderConversation(_ messages: [ChatMessage], title: String) -> UIImage {
        let width: CGFloat = 375
        let padding: CGFloat = 16

        // Calculate total height
        var totalHeight: CGFloat = 60 // Header
        for msg in messages.prefix(20) { // Limit to 20 messages
            let size = (msg.content as NSString).boundingRect(
                with: CGSize(width: width - padding * 2 - 24, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin],
                attributes: [.font: UIFont.systemFont(ofSize: 14)],
                context: nil
            )
            totalHeight += size.height + 50
        }
        totalHeight += 40 // Footer

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: totalHeight))
        return renderer.image { context in
            UIColor.systemBackground.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: totalHeight))

            // Title
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 16),
                .foregroundColor: UIColor.label
            ]
            (title as NSString).draw(at: CGPoint(x: padding, y: 16), withAttributes: titleAttrs)

            var yOffset: CGFloat = 48
            let contentFont = UIFont.systemFont(ofSize: 14)
            let roleFont = UIFont.boldSystemFont(ofSize: 11)

            for msg in messages.prefix(20) {
                let role = msg.role == .user ? "You" : "Gemma"
                let bgColor: UIColor = msg.role == .user ? .systemBlue : .systemGray5
                let textColor: UIColor = msg.role == .user ? .white : .label

                let contentSize = (msg.content as NSString).boundingRect(
                    with: CGSize(width: width - padding * 2 - 24, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin],
                    attributes: [.font: contentFont],
                    context: nil
                )
                let bubbleH = contentSize.height + 36

                let bubbleRect = CGRect(x: padding, y: yOffset, width: width - padding * 2, height: bubbleH)
                let path = UIBezierPath(roundedRect: bubbleRect, cornerRadius: 12)
                bgColor.setFill()
                path.fill()

                (role as NSString).draw(
                    at: CGPoint(x: padding + 12, y: yOffset + 8),
                    withAttributes: [.font: roleFont, .foregroundColor: textColor]
                )
                (msg.content as NSString).draw(
                    in: CGRect(x: padding + 12, y: yOffset + 24, width: width - padding * 2 - 24, height: contentSize.height + 5),
                    withAttributes: [.font: contentFont, .foregroundColor: textColor]
                )

                yOffset += bubbleH + 8
            }
        }
    }

    static func share(image: UIImage) {
        let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        if let vc = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows.first?.rootViewController {
            vc.present(activityVC, animated: true)
        }
    }
}
