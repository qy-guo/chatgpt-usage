import Foundation

public struct UsageResetRefreshDecision: Equatable {
    public var shouldRefreshNow: Bool
    public var nextRefreshDate: Date?

    public init(shouldRefreshNow: Bool, nextRefreshDate: Date?) {
        self.shouldRefreshNow = shouldRefreshNow
        self.nextRefreshDate = nextRefreshDate
    }
}

public enum UsageResetSchedule {
    public static func nextFiveHourResetDate(
        from fiveHourUsage: String?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Date? {
        guard let fiveHourUsage else {
            return nil
        }

        if let fullDate = fullDate(from: fiveHourUsage, now: now, calendar: calendar) {
            return fullDate
        }

        guard let time = timeOfDay(from: fiveHourUsage) else {
            return nil
        }

        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = time.hour
        components.minute = time.minute
        components.second = 0

        guard let candidate = calendar.date(from: components) else {
            return nil
        }

        if candidate > now {
            return candidate
        }

        return calendar.date(byAdding: .day, value: 1, to: candidate)
    }

    public static func nextWeeklyResetDate(
        from weeklyUsage: String?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Date? {
        guard let weeklyUsage else {
            return nil
        }

        return fullDate(from: weeklyUsage, now: now, calendar: calendar)
    }

    public static func refreshDecision(
        snapshot: UsageSnapshot,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> UsageResetRefreshDecision {
        refreshDecision(
            fiveHourUsage: snapshot.fiveHourUsage,
            weeklyUsage: snapshot.weeklyUsage,
            lastReadAt: snapshot.lastReadAt,
            now: now,
            calendar: calendar
        )
    }

    public static func refreshDecision(
        fiveHourUsage: String?,
        weeklyUsage: String?,
        lastReadAt: Date?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> UsageResetRefreshDecision {
        var futureDates: [Date] = []
        var shouldRefreshNow = false

        if let fiveHourUsage {
            if let fullDate = fullDate(from: fiveHourUsage, now: now, calendar: calendar) {
                if fullDate <= now {
                    shouldRefreshNow = true
                } else {
                    futureDates.append(fullDate)
                }
            } else if let time = timeOfDay(from: fiveHourUsage),
                      let todayResetDate = date(onSameDayAs: now, time: time, calendar: calendar) {
                if todayResetDate > now {
                    futureDates.append(todayResetDate)
                } else if let lastReadAt,
                          lastReadAt < todayResetDate {
                    shouldRefreshNow = true
                } else if let tomorrowResetDate = calendar.date(byAdding: .day, value: 1, to: todayResetDate) {
                    futureDates.append(tomorrowResetDate)
                }
            }
        }

        if let weeklyResetDate = nextWeeklyResetDate(from: weeklyUsage, now: now, calendar: calendar) {
            if weeklyResetDate <= now {
                shouldRefreshNow = true
            } else {
                futureDates.append(weeklyResetDate)
            }
        }

        if shouldRefreshNow {
            return UsageResetRefreshDecision(shouldRefreshNow: true, nextRefreshDate: nil)
        }

        return UsageResetRefreshDecision(
            shouldRefreshNow: false,
            nextRefreshDate: futureDates.min()
        )
    }

    private static func date(
        onSameDayAs referenceDate: Date,
        time: (hour: Int, minute: Int),
        calendar: Calendar
    ) -> Date? {
        var components = calendar.dateComponents([.year, .month, .day], from: referenceDate)
        components.hour = time.hour
        components.minute = time.minute
        components.second = 0
        return calendar.date(from: components)
    }

    private static func fullDate(
        from value: String,
        now: Date,
        calendar: Calendar
    ) -> Date? {
        fullChineseDate(from: value, calendar: calendar)
            ?? fullNumericDate(from: value, calendar: calendar)
            ?? fullEnglishDate(from: value, now: now, calendar: calendar)
    }

    private static func fullChineseDate(from value: String, calendar: Calendar) -> Date? {
        guard let groups = firstMatchGroups(
            in: value,
            pattern: #"(\d{4})年\s*(\d{1,2})月\s*(\d{1,2})日\s*(\d{1,2}):(\d{2})"#
        ),
              groups.count == 5,
              let year = Int(groups[0]),
              let month = Int(groups[1]),
              let day = Int(groups[2]),
              let hour = Int(groups[3]),
              let minute = Int(groups[4]),
              isValidTime(hour: hour, minute: minute) else {
            return nil
        }

        return calendar.date(
            from: DateComponents(
                timeZone: calendar.timeZone,
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute
            )
        )
    }

    private static func fullNumericDate(from value: String, calendar: Calendar) -> Date? {
        guard let groups = firstMatchGroups(
            in: value,
            pattern: #"(\d{4})[-/](\d{1,2})[-/](\d{1,2})[ T,]+(\d{1,2}):(\d{2})\s*(am|pm)?"#,
            options: [.caseInsensitive]
        ),
              groups.count == 6,
              let year = Int(groups[0]),
              let month = Int(groups[1]),
              let day = Int(groups[2]),
              let rawHour = Int(groups[3]),
              let minute = Int(groups[4]),
              let hour = normalizedHour(rawHour, meridiem: groups[5]),
              isValidTime(hour: hour, minute: minute) else {
            return nil
        }

        return calendar.date(
            from: DateComponents(
                timeZone: calendar.timeZone,
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute
            )
        )
    }

    private static func fullEnglishDate(
        from value: String,
        now: Date,
        calendar: Calendar
    ) -> Date? {
        guard let groups = firstMatchGroups(
            in: value,
            pattern: #"\b(january|jan|february|feb|march|mar|april|apr|may|june|jun|july|jul|august|aug|september|sep|sept|october|oct|november|nov|december|dec)\.?\s+(\d{1,2})(?:st|nd|rd|th)?(?:,\s*|\s+)(?:(\d{4})(?:,\s*|\s+))?(?:at\s*)?(\d{1,2}):(\d{2})\s*(am|pm)?\b"#,
            options: [.caseInsensitive]
        ),
              groups.count == 6,
              let month = englishMonthNumber(groups[0]),
              let day = Int(groups[1]),
              let rawHour = Int(groups[3]),
              let minute = Int(groups[4]),
              let hour = normalizedHour(rawHour, meridiem: groups[5]),
              isValidTime(hour: hour, minute: minute) else {
            return nil
        }

        let year = Int(groups[2]) ?? calendar.component(.year, from: now)
        return calendar.date(
            from: DateComponents(
                timeZone: calendar.timeZone,
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute
            )
        )
    }

    private static func timeOfDay(from value: String) -> (hour: Int, minute: Int)? {
        guard let groups = firstMatchGroups(
            in: value,
            pattern: #"(?<!\d)(\d{1,2}):(\d{2})\s*(am|pm)?(?![a-zA-Z0-9])"#,
            options: [.caseInsensitive]
        ),
              groups.count == 3,
              let hour = Int(groups[0]),
              let minute = Int(groups[1]),
              let normalizedHour = normalizedHour(hour, meridiem: groups[2]),
              isValidTime(hour: normalizedHour, minute: minute) else {
            return nil
        }

        return (normalizedHour, minute)
    }

    private static func isValidTime(hour: Int, minute: Int) -> Bool {
        (0...23).contains(hour) && (0...59).contains(minute)
    }

    private static func normalizedHour(_ hour: Int, meridiem: String) -> Int? {
        let meridiem = meridiem.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !meridiem.isEmpty else {
            return hour
        }

        guard (1...12).contains(hour) else {
            return nil
        }

        if meridiem == "am" {
            return hour == 12 ? 0 : hour
        }

        if meridiem == "pm" {
            return hour == 12 ? 12 : hour + 12
        }

        return nil
    }

    private static func englishMonthNumber(_ value: String) -> Int? {
        switch value.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased() {
        case "january", "jan":
            1
        case "february", "feb":
            2
        case "march", "mar":
            3
        case "april", "apr":
            4
        case "may":
            5
        case "june", "jun":
            6
        case "july", "jul":
            7
        case "august", "aug":
            8
        case "september", "sep", "sept":
            9
        case "october", "oct":
            10
        case "november", "nov":
            11
        case "december", "dec":
            12
        default:
            nil
        }
    }

    private static func firstMatchGroups(
        in value: String,
        pattern: String,
        options: NSRegularExpression.Options = []
    ) -> [String]? {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: options) else {
            return nil
        }

        let nsValue = value as NSString
        let range = NSRange(location: 0, length: nsValue.length)
        guard let match = expression.firstMatch(in: value, range: range),
              match.numberOfRanges > 1 else {
            return nil
        }

        return (1..<match.numberOfRanges).map { index in
            let range = match.range(at: index)
            guard range.location != NSNotFound else {
                return ""
            }

            return nsValue.substring(with: range)
        }
    }
}
