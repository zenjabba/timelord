#if os(iOS)
import Foundation
import WebKit

public enum PDFGenerationService {
    public enum PDFError: Error, LocalizedError {
        case templateNotFound
        case renderingFailed
        case pdfCreationFailed

        public var errorDescription: String? {
            switch self {
            case .templateNotFound:
                return "Invoice HTML template not found in bundle."
            case .renderingFailed:
                return "Failed to render invoice content."
            case .pdfCreationFailed:
                return "Failed to create PDF from rendered content."
            }
        }
    }

    @MainActor
    public static func generatePDF(for invoice: Invoice) async throws -> Data {
        let html = try buildHTML(for: invoice)
        let data = try await renderPDF(from: html)
        return data
    }

    // MARK: - HTML Building

    private static func buildHTML(for invoice: Invoice) throws -> String {
        guard let templateURL = Bundle.main.url(forResource: "InvoiceTemplate", withExtension: "html"),
              let template = try? String(contentsOf: templateURL, encoding: .utf8) else {
            throw PDFError.templateNotFound
        }

        var html = template

        // Business info
        html = html.replacingOccurrences(of: "{{businessName}}", with: escapeHTML(invoice.businessName ?? ""))
        html = html.replacingOccurrences(of: "{{businessAddress}}", with: escapeHTML(invoice.businessAddress ?? "").replacingOccurrences(of: "\n", with: "<br>"))

        // Invoice details
        html = html.replacingOccurrences(of: "{{invoiceNumber}}", with: escapeHTML(invoice.invoiceNumber))
        html = html.replacingOccurrences(of: "{{issueDate}}", with: formatDate(invoice.issueDate))
        html = html.replacingOccurrences(of: "{{dueDate}}", with: invoice.dueDate.map(formatDate) ?? "")

        let hasDueDate = invoice.dueDate != nil
        html = html.replacingOccurrences(of: "{{dueDateDisplay}}", with: hasDueDate ? "table-row" : "none")

        // Client info
        html = html.replacingOccurrences(of: "{{clientName}}", with: escapeHTML(invoice.client?.name ?? ""))
        html = html.replacingOccurrences(of: "{{clientEmail}}", with: escapeHTML(invoice.client?.email ?? ""))

        let hasEmail = invoice.client?.email != nil && !(invoice.client?.email?.isEmpty ?? true)
        html = html.replacingOccurrences(of: "{{clientEmailDisplay}}", with: hasEmail ? "block" : "none")

        // Line items
        let lineItemsHTML = invoice.sortedLineItems.map { item in
            """
            <tr>
                <td>\(escapeHTML(item.descriptionText))</td>
                <td class="number">\(item.quantity.formatted())</td>
                <td class="number">\(CurrencyService.format(amount: item.unitPrice, currencyCode: invoice.currencyCode))</td>
                <td class="number">\(CurrencyService.format(amount: item.amount, currencyCode: invoice.currencyCode))</td>
            </tr>
            """
        }.joined(separator: "\n")
        html = html.replacingOccurrences(of: "{{lineItems}}", with: lineItemsHTML)

        // Totals
        html = html.replacingOccurrences(of: "{{subtotal}}", with: CurrencyService.format(amount: invoice.subtotal, currencyCode: invoice.currencyCode))
        html = html.replacingOccurrences(of: "{{totalAmount}}", with: CurrencyService.format(amount: invoice.totalAmount, currencyCode: invoice.currencyCode))

        let hasTax = (invoice.taxRate ?? 0) > 0
        html = html.replacingOccurrences(of: "{{taxDisplay}}", with: hasTax ? "table-row" : "none")
        if hasTax, let taxRate = invoice.taxRate {
            let taxAmount = invoice.subtotal * taxRate / 100
            html = html.replacingOccurrences(of: "{{taxRate}}", with: "\(taxRate.formatted())%")
            html = html.replacingOccurrences(of: "{{taxAmount}}", with: CurrencyService.format(amount: taxAmount, currencyCode: invoice.currencyCode))
        } else {
            html = html.replacingOccurrences(of: "{{taxRate}}", with: "")
            html = html.replacingOccurrences(of: "{{taxAmount}}", with: "")
        }

        // Notes
        let hasNotes = invoice.notes != nil && !(invoice.notes?.isEmpty ?? true)
        html = html.replacingOccurrences(of: "{{notesDisplay}}", with: hasNotes ? "block" : "none")
        html = html.replacingOccurrences(of: "{{notes}}", with: escapeHTML(invoice.notes ?? "").replacingOccurrences(of: "\n", with: "<br>"))

        // Status
        html = html.replacingOccurrences(of: "{{status}}", with: invoice.status.capitalized)

        return html
    }

    // MARK: - PDF Rendering

    @MainActor
    private static func renderPDF(from html: String) async throws -> Data {
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 595, height: 842))
        webView.isOpaque = false
        webView.backgroundColor = .white

        return try await withCheckedThrowingContinuation { continuation in
            let delegate = PDFNavigationDelegate { result in
                switch result {
                case .success(let data):
                    continuation.resume(returning: data)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            // Hold a strong reference via objc associated object
            objc_setAssociatedObject(webView, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
            webView.navigationDelegate = delegate
            webView.loadHTMLString(html, baseURL: nil)
        }
    }

    // MARK: - Helpers

    private static func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Navigation Delegate

private final class PDFNavigationDelegate: NSObject, WKNavigationDelegate {
    let completion: @MainActor (Result<Data, Error>) -> Void

    init(completion: @escaping @MainActor (Result<Data, Error>) -> Void) {
        self.completion = completion
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            // Small delay to ensure rendering is complete
            try? await Task.sleep(for: .milliseconds(100))

            let config = WKPDFConfiguration()
            config.rect = CGRect(x: 0, y: 0, width: 595, height: 842) // A4 at 72dpi

            do {
                let data = try await webView.pdf(configuration: config)
                completion(.success(data))
            } catch {
                completion(.failure(PDFGenerationService.PDFError.pdfCreationFailed))
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            completion(.failure(PDFGenerationService.PDFError.renderingFailed))
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            completion(.failure(PDFGenerationService.PDFError.renderingFailed))
        }
    }
}
#endif
