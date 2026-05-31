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

        if let fullDate = fullChineseDate(from: fiveHourUsage, calendar: calendar) {
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

        _ = now
        return fullChineseDate(from: weeklyUsage, calendar: calendar)
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
            if let fullDate = fullChineseDate(from: fiveHourUsage, calendar: calendar) {
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

    private static func timeOfDay(from value: String) -> (hour: Int, minute: Int)? {
        guard let groups = firstMatchGroups(
            in: value,
            pattern: #"(?<!\d)(\d{1,2}):(\d{2})(?!\d)"#
        ),
              groups.count == 2,
              let hour = Int(groups[0]),
              let minute = Int(groups[1]),
              isValidTime(hour: hour, minute: minute) else {
            return nil
        }

        return (hour, minute)
    }

    private static func isValidTime(hour: Int, minute: Int) -> Bool {
        (0...23).contains(hour) && (0...59).contains(minute)
    }

    private static func firstMatchGroups(in value: String, pattern: String) -> [String]? {
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let nsValue = value as NSString
        let range = NSRange(location: 0, length: nsValue.length)
        guard let match = expression.firstMatch(in: value, range: range),
              match.numberOfRanges > 1 else {
            return nil
        }

        return (1..<match.numberOfRanges).compactMap { index in
            let range = match.range(at: index)
            guard range.location != NSNotFound else {
                return nil
            }

            return nsValue.substring(with: range)
        }
    }
}
