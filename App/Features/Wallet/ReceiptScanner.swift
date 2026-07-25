import SwiftUI
import UIKit
import Vision
import VisionKit

// The real capture + read pipeline behind Scan. VisionKit's document camera does
// edge detection + perspective correction; Vision's text recognizer reads the
// cropped image on device (no network), and a small heuristic parser pulls out
// merchant / date / total. Everything the parser can't be sure of stays editable
// in the review form — OCR is a head start, not the last word.

/// A parsed receipt. Value type (Sendable) so it can cross the OCR concurrency hop.
struct ParsedReceipt: Sendable {
    var merchant: String?
    var date: Date?
    var total: Decimal?
    var fieldsFound: Int
    var rawText: String

    static let empty = ParsedReceipt(merchant: nil, date: nil, total: nil, fieldsFound: 0, rawText: "")
}

// MARK: - VisionKit document scanner (UIKit bridge)

/// Presents `VNDocumentCameraViewController` and returns the first scanned page.
/// Only available on-device (`VNDocumentCameraViewController.isSupported`).
struct DocumentScanner: UIViewControllerRepresentable {
    /// Called with the captured image, or `nil` if the user cancelled / it failed.
    let onComplete: (UIImage?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onComplete: onComplete) }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}

    @MainActor
    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        private let onComplete: (UIImage?) -> Void
        private var finished = false

        init(onComplete: @escaping (UIImage?) -> Void) { self.onComplete = onComplete }

        // VisionKit calls its delegate on the main thread, but the protocol isn't
        // @MainActor-annotated — so satisfy it with nonisolated methods and hop back
        // via assumeIsolated (safe: we are already on main).
        nonisolated func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            let image = scan.pageCount > 0 ? scan.imageOfPage(at: 0) : nil
            MainActor.assumeIsolated { self.finish(image) }
        }

        nonisolated func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            MainActor.assumeIsolated { self.finish(nil) }
        }

        nonisolated func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            MainActor.assumeIsolated { self.finish(nil) }
        }

        private func finish(_ image: UIImage?) {
            guard !finished else { return }
            finished = true
            onComplete(image)
        }
    }
}

// MARK: - On-device OCR + parsing

enum ReceiptOCR {
    /// Recognize text in the image and parse merchant / date / total. Runs off the
    /// main thread; only `Data` (Sendable) crosses the concurrency boundary.
    static func scan(_ image: UIImage) async -> ParsedReceipt {
        guard let data = image.jpegData(compressionQuality: 0.9) else { return .empty }
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: recognize(imageData: data))
            }
        }
    }

    private nonisolated static func recognize(imageData: Data) -> ParsedReceipt {
        guard let cg = UIImage(data: imageData)?.cgImage else { return .empty }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        do { try handler.perform([request]) } catch { return .empty }

        // Top-to-bottom reading order (Vision's origin is bottom-left, so higher maxY = higher up).
        let lines: [String] = (request.results ?? [])
            .sorted { $0.boundingBox.maxY > $1.boundingBox.maxY }
            .compactMap { $0.topCandidates(1).first?.string }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return parse(lines: lines)
    }

    // MARK: Heuristic parser

    static func parse(lines: [String]) -> ParsedReceipt {
        let merchant = findMerchant(lines)
        let total = findTotal(lines)
        let date = findDate(lines)
        let found = [merchant != nil, date != nil, total != nil].filter { $0 }.count
        return ParsedReceipt(
            merchant: merchant,
            date: date,
            total: total,
            fieldsFound: found,
            rawText: lines.joined(separator: "\n")
        )
    }

    /// Merchant = the first prominent line near the top that reads like a name,
    /// not a price, date, phone number, or address.
    private static func findMerchant(_ lines: [String]) -> String? {
        for line in lines.prefix(6) {
            let letters = line.filter { $0.isLetter }.count
            if letters < 3 { continue }
            if looksLikeDate(line) || looksLikeAmountOnly(line) || looksLikePhone(line) { continue }
            let lower = line.lowercased()
            if lower.contains("receipt") || lower.contains("welcome") || lower.contains("thank") { continue }
            return line.count > 40 ? String(line.prefix(40)) : line
        }
        return nil
    }

    /// Total = the amount on a line mentioning "total" (excluding subtotal), else
    /// the largest currency amount on the receipt.
    private static func findTotal(_ lines: [String]) -> Decimal? {
        var labelledTotal: Decimal?
        for line in lines {
            let lower = line.lowercased()
            guard lower.contains("total") else { continue }
            if lower.contains("subtotal") && labelledTotal != nil { continue }
            if let amount = amounts(in: line).last {
                if lower.contains("subtotal") {
                    labelledTotal = labelledTotal ?? amount
                } else {
                    labelledTotal = amount // a plain/grand "total" line wins
                }
                if !lower.contains("subtotal") { return amount }
            }
        }
        if let labelledTotal { return labelledTotal }
        return lines.flatMap { amounts(in: $0) }.max()
    }

    private static func findDate(_ lines: [String]) -> Date? {
        for line in lines {
            if let date = firstDate(in: line) { return date }
        }
        return nil
    }

    // MARK: Field detectors

    private static func amounts(in line: String) -> [Decimal] {
        let pattern = #"(?<![\d.])\d{1,6}[.,]\d{2}(?![\d])"#
        return matches(pattern, in: line).compactMap { raw in
            Decimal(string: raw.replacingOccurrences(of: ",", with: "."))
        }
    }

    private static func looksLikeAmountOnly(_ line: String) -> Bool {
        let stripped = line.filter { !$0.isWhitespace }
        return stripped.range(of: #"^[$€£]?\d{1,6}[.,]\d{2}$"#, options: .regularExpression) != nil
    }

    private static func looksLikePhone(_ line: String) -> Bool {
        let digits = line.filter(\.isNumber).count
        return digits >= 7 && line.filter(\.isLetter).count <= 2
    }

    private static func looksLikeDate(_ line: String) -> Bool { firstDate(in: line) != nil }

    private static let dateFormats = [
        "MM/dd/yyyy", "M/d/yyyy", "MM/dd/yy", "M/d/yy",
        "MM-dd-yyyy", "yyyy-MM-dd", "MMM d, yyyy", "MMM dd, yyyy",
        "MMMM d, yyyy", "d MMM yyyy",
    ]

    private static func firstDate(in line: String) -> Date? {
        let patterns = [
            #"\d{1,2}[/-]\d{1,2}[/-]\d{2,4}"#,
            #"\d{4}-\d{2}-\d{2}"#,
            #"[A-Za-z]{3,9}\.?\s+\d{1,2},?\s+\d{4}"#,
            #"\d{1,2}\s+[A-Za-z]{3,9}\.?\s+\d{4}"#,
        ]
        for pattern in patterns {
            for token in matches(pattern, in: line) {
                let cleaned = token.replacingOccurrences(of: ".", with: "")
                let fmt = DateFormatter()
                fmt.locale = Locale(identifier: "en_US_POSIX")
                for format in dateFormats {
                    fmt.dateFormat = format
                    if let date = fmt.date(from: cleaned) { return date }
                }
            }
        }
        return nil
    }

    private static func matches(_ pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap {
            Range($0.range, in: text).map { String(text[$0]) }
        }
    }
}
