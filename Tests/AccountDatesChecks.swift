import Foundation

@main
struct AccountDatesChecks {
    static func main() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Moscow")!
        func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
        }
        let september = AccountDates(now: date(2026, 9, 19), calendar: calendar)
        precondition(september.month == "September")
        precondition(september.paymentDue == "Due by 26 September")
        let boundary = AccountDates(now: date(2026, 9, 28), calendar: calendar)
        precondition(boundary.month == "September")
        precondition(boundary.paymentDue == "Due by 5 October")
        let nextYear = AccountDates(now: date(2026, 12, 29), calendar: calendar)
        precondition(nextYear.month == "December")
        precondition(nextYear.paymentDue == "Due by 5 January")
        print("PASS: current month, upcoming demo deadline, month and year rollover")
    }
}
