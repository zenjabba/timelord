import Foundation

public extension Decimal {
    var currencyString: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: self as NSDecimalNumber) ?? "\(self)"
    }

    func formatted(currencyCode: String) -> String {
        CurrencyService.format(amount: self, currencyCode: currencyCode)
    }
}
