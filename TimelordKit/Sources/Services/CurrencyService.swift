import Foundation

public enum CurrencyService {
    public static let commonCurrencies: [(code: String, name: String, symbol: String)] = [
        ("USD", "US Dollar", "$"),
        ("EUR", "Euro", "\u{20AC}"),
        ("GBP", "British Pound", "\u{00A3}"),
        ("CAD", "Canadian Dollar", "CA$"),
        ("AUD", "Australian Dollar", "A$"),
        ("JPY", "Japanese Yen", "\u{00A5}"),
        ("CHF", "Swiss Franc", "CHF"),
        ("CNY", "Chinese Yuan", "\u{00A5}"),
        ("SEK", "Swedish Krona", "kr"),
        ("NZD", "New Zealand Dollar", "NZ$"),
        ("MXN", "Mexican Peso", "MX$"),
        ("SGD", "Singapore Dollar", "S$"),
        ("HKD", "Hong Kong Dollar", "HK$"),
        ("NOK", "Norwegian Krone", "kr"),
        ("KRW", "South Korean Won", "\u{20A9}"),
        ("INR", "Indian Rupee", "\u{20B9}"),
        ("BRL", "Brazilian Real", "R$"),
        ("ZAR", "South African Rand", "R"),
        ("DKK", "Danish Krone", "kr"),
        ("PLN", "Polish Zloty", "z\u{0142}"),
    ]

    public static func format(amount: Decimal, currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.maximumFractionDigits = currencyCode == "JPY" || currencyCode == "KRW" ? 0 : 2
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(currencyCode) \(amount)"
    }

    public static func symbol(for currencyCode: String) -> String {
        commonCurrencies.first { $0.code == currencyCode }?.symbol
            ?? currencyCode
    }

    public static func name(for currencyCode: String) -> String {
        commonCurrencies.first { $0.code == currencyCode }?.name
            ?? currencyCode
    }

    public static var allCurrencyCodes: [String] {
        Locale.commonISOCurrencyCodes
    }
}
