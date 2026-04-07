import Foundation
import Testing
@testable import TimelordKit

@Suite("CurrencyService Tests")
struct CurrencyServiceTests {
    @Test("Format USD amount")
    func formatUSD() {
        let result = CurrencyService.format(amount: 150.50, currencyCode: "USD")
        #expect(result.contains("150"))
        #expect(result.contains("50"))
    }

    @Test("Symbol lookup")
    func symbolLookup() {
        #expect(CurrencyService.symbol(for: "USD") == "$")
        #expect(CurrencyService.symbol(for: "GBP") == "\u{00A3}")
        #expect(CurrencyService.symbol(for: "EUR") == "\u{20AC}")
    }

    @Test("Name lookup")
    func nameLookup() {
        #expect(CurrencyService.name(for: "USD") == "US Dollar")
        #expect(CurrencyService.name(for: "GBP") == "British Pound")
    }

    @Test("Unknown currency returns code as symbol")
    func unknownCurrency() {
        #expect(CurrencyService.symbol(for: "XYZ") == "XYZ")
    }

    @Test("Common currencies list is not empty")
    func commonCurrenciesExist() {
        #expect(!CurrencyService.commonCurrencies.isEmpty)
        #expect(CurrencyService.commonCurrencies.count >= 10)
    }
}
