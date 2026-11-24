import Foundation

enum MeasureFormat {
    static func mm(_ value: Double) -> String {
        let rounded = value.rounded()
        return (integer.string(from: NSNumber(value: rounded)) ?? String(format: "%.0f", rounded)) + " mm"
    }

    static func cm(fromMM value: Double) -> String {
        let centimetres = value / 10
        return (centimetre.string(from: NSNumber(value: centimetres)) ?? String(format: "%.1f", centimetres)) + " cm"
    }

    static func area(_ squareMetres: Double) -> String {
        (areaFormatter.string(from: NSNumber(value: squareMetres)) ?? String(format: "%.3f", squareMetres)) + " m²"
    }

    static func pair(width: Double, height: Double) -> String {
        "\(mm(width)) × \(mm(height))"
    }

    static func date(_ date: Date) -> String {
        day.string(from: date)
    }

    static func dateTime(_ date: Date) -> String {
        stamp.string(from: date)
    }

    static func fileStamp(_ date: Date) -> String {
        file.string(from: date)
    }

    private static let integer: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "zh_HK")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    private static let centimetre: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "zh_HK")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 1
        return formatter
    }()

    private static let areaFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "zh_HK")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 3
        formatter.maximumFractionDigits = 3
        return formatter
    }()

    private static let day: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_HK")
        formatter.dateFormat = "yyyy年M月d日"
        return formatter
    }()

    private static let stamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_HK")
        formatter.dateFormat = "yyyy年M月d日 HH:mm"
        return formatter
    }()

    private static let file: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_HK")
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()
}

enum LengthParsing {
    static func millimetres(_ text: String) -> Double? {
        let cleaned = text
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(cleaned), value > 0, value.isFinite else { return nil }
        return value
    }
}
