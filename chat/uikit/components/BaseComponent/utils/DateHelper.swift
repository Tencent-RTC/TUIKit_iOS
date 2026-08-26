
class DateHelper {
    private static let sundayFirstWeekday = 1

    private static let mondayFirstWeekday = 2

    private static let mondayBasedWeekdayShift = 5

    private static let daysPerWeek = 7

    private static let secondsPerMinute = 60

    private static let secondsPerHour = 3600

    private static var isChineseLanguage: Bool {
        LanguageHelper.getCurrentLanguage().hasPrefix("zh")
    }

    private static var shortDatePattern: String {
        isChineseLanguage ? "M月d日" : "M/d/yy"
    }

    private static var fullDatePattern: String {
        isChineseLanguage ? "yyyy年M月d日" : "M/d/yy"
    }

    static func convertDateToMessageTimeStr(_ date: Date) -> String {
        if date == Date.distantPast {
            return ""
        }
        let calendar = Calendar.current
        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        timeFormatter.dateFormat = "HH:mm"
        let timeString = timeFormatter.string(from: date)

        if calendar.isDateInToday(date) {
            return timeString
        }
        if calendar.isDateInYesterday(date) {
            return "\(LocalizedChatString("Yesterday")) \(timeString)"
        }

        let now = Date()
        let nowComponents = calendar.dateComponents([.year], from: now)
        let dateComponents = calendar.dateComponents([.year], from: date)
        let isSameYear = nowComponents.year == dateComponents.year
        let isSameWeek = startOfWeekMonday(now) == startOfWeekMonday(date)
        let languageLocale = Locale(identifier: LanguageHelper.getCurrentLanguage())

        if isSameYear && isSameWeek {
            let weekdayFormatter = DateFormatter()
            weekdayFormatter.dateFormat = "EEEE"
            weekdayFormatter.locale = languageLocale
            return "\(weekdayFormatter.string(from: date)) \(timeString)"
        }

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = isSameYear ? Self.shortDatePattern : Self.fullDatePattern
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")
        return "\(dayFormatter.string(from: date)) \(timeString)"
    }

    static func convertDateToYMDStr(_ date: Date) -> String {
        if date == Date.distantPast {
            return ""
        }

        let dateFmt = DateFormatter()
        dateFmt.locale = Locale(identifier: "en_US_POSIX")

        let calendar = Calendar.current
        var customCalendar = calendar
        customCalendar.firstWeekday = sundayFirstWeekday

        let now = Date()
        let nowComponent = customCalendar.dateComponents([.day, .month, .year, .weekOfMonth], from: now)
        let dateComponent = customCalendar.dateComponents([.day, .month, .year, .weekOfMonth], from: date)

        if nowComponent.year == dateComponent.year {
            if nowComponent.month == dateComponent.month {
                if nowComponent.weekOfMonth == dateComponent.weekOfMonth {
                    if nowComponent.day == dateComponent.day {
                        dateFmt.dateFormat = "HH:mm"
                    } else {
                        dateFmt.dateFormat = "EEEE"
                        let identifier = LanguageHelper.getCurrentLanguage()
                        dateFmt.locale = Locale(identifier: identifier)
                    }
                } else {
                    dateFmt.dateFormat = Self.shortDatePattern
                }
            } else {
                dateFmt.dateFormat = Self.shortDatePattern
            }
        } else {
            dateFmt.dateFormat = Self.fullDatePattern
        }
        return dateFmt.string(from: date)
    }

    static func formatDurationSeconds(_ totalSeconds: Int) -> String {
        if totalSeconds <= 0 {
            return "00:00"
        }
        let hours = totalSeconds / secondsPerHour
        let minutes = totalSeconds % secondsPerHour / secondsPerMinute
        let seconds = totalSeconds % secondsPerMinute
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    static func formatDurationMillis(_ milliseconds: Int) -> String {
        return formatDurationSeconds(milliseconds / 1000)
    }

    static func formatCallDuration(_ totalSeconds: Int) -> String {
        let safeSeconds = max(totalSeconds, 0)
        return String(format: "%02d:%02d", safeSeconds / secondsPerMinute, safeSeconds % secondsPerMinute)
    }

    private static func startOfWeekMonday(_ date: Date) -> Date {
        var calendar = Calendar.current
        calendar.firstWeekday = mondayFirstWeekday
        let startOfDay = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: startOfDay)
        let mondayBasedIndex = (weekday + mondayBasedWeekdayShift) % daysPerWeek
        return calendar.date(byAdding: .day, value: -mondayBasedIndex, to: startOfDay) ?? startOfDay
    }
}
