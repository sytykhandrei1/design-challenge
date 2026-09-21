import Foundation

/// Relative dates for demo data, not a real account's billing schedule.
/// Keep the English design copy while following the device's date/time zone.
struct AccountDates {
    let month: String
    let paymentDue: String

    init(now: Date, calendar: Calendar = .autoupdatingCurrent) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "MMMM"
        month = formatter.string(from: now)
        // A rolling seven-day demo deadline never leaves the account overdue.
        let due = calendar.date(byAdding: .day, value: 7, to: now) ?? now
        formatter.dateFormat = "d MMMM"
        paymentDue = "Due by \(formatter.string(from: due))"
    }
}
