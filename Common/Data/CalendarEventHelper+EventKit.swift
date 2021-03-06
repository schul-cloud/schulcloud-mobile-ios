//
//  Created for schulcloud-mobile-ios under GPL-3.0 license.
//  Copyright © HPI. All rights reserved.
//

import BrightFutures
import EventKit
import Foundation

// MARK: Extension with EvenKit convenience
extension CalendarEventHelper {

    private static var eventStore = EKEventStore()
    private static var calendar: EKCalendar?

    private enum Keys {
        static let shouldSynchronize = "org.schul-cloud.calendar.eventKitShouldSynchronize"
        static let calendarIdentifier = "org.schul-cloud.calendar.identifier"
    }

    public struct EventKitSettings {

        public static var current = EventKitSettings()
        public var shouldSynchonize: Bool {
            get {
                return UserDefaults.standard.bool(forKey: Keys.shouldSynchronize)
            }
            set {
                UserDefaults.standard.set(newValue, forKey: Keys.shouldSynchronize)
                UserDefaults.standard.synchronize()
            }
        }

        public var calendarIdentifier: String? {
            get {
                return UserDefaults.standard.string(forKey: Keys.calendarIdentifier)
            }

            set {
                UserDefaults.standard.set(newValue, forKey: Keys.calendarIdentifier)
                UserDefaults.standard.synchronize()
            }
        }
    }

    // MARK: Event management
    private static func update(event: EKEvent, with calendarEvent: CalendarEvent) {
        event.title = calendarEvent.title
        event.notes = calendarEvent.description
        event.location = calendarEvent.location
        event.startDate = calendarEvent.start
        event.endDate = calendarEvent.end
        event.recurrenceRules = {
            guard let rule = calendarEvent.recurrenceRule else { return nil }
            return [rule.ekRecurrenceRule]
        }()
    }

    // MARK: Calendar management
    public static func requestCalendarPermission() -> Future<Void, SCError> {
        let promise = Promise<Void, SCError>()

        switch EKEventStore.authorizationStatus(for: .event) {
        case .authorized:
            promise.success(Void())
        case .notDetermined:
            self.eventStore.requestAccess(to: .event) { granted, error in
                if granted && error == nil {
                    promise.success(Void())
                } else {
                    promise.failure(SCError.other("Missing Calendar Permission: \(error!.localizedDescription)"))
                }
            }
        default:
            promise.failure(SCError.other("Cannot request permision for calendar"))
        }

        return promise.future
    }

    public static var currentCalenderPermissionStatus: EKAuthorizationStatus {
        return EKEventStore.authorizationStatus(for: .event)
    }

    public static func fetchCalendar() -> EKCalendar? {
        if let calendar = self.calendar { return calendar }

        if let calendarIdentifier = EventKitSettings.current.calendarIdentifier,
            let foundCalendar = eventStore.calendar(withIdentifier: calendarIdentifier) {
            self.calendar = foundCalendar
            return calendar
        }

        if let calendar = eventStore.calendars(for: .event).first (where: { $0.title == Brand.default.name }) {
            self.calendar = calendar
            return calendar
        }

        return nil
    }

    public static func createCalendar() -> EKCalendar? {
        guard let source = eventStore.sources.first(where: { return $0.sourceType == EKSourceType.subscribed }) else {
            return nil
        }

        let calendar = EKCalendar(for: .event, eventStore: self.eventStore)
        calendar.title = Brand.default.name
        calendar.source = source

        do {
            try self.eventStore.saveCalendar(calendar, commit: true)
        } catch {
            return nil
        }

        EventKitSettings.current.calendarIdentifier = calendar.calendarIdentifier

        self.calendar = calendar
        return calendar
    }

    // This function pushes new or update events to the calander
    public static func push(events: [CalendarEvent], to calendar: EKCalendar) throws {
        CoreDataHelper.persistentContainer.performBackgroundTask { context in
            for var calendarEvent in events {
                var event: EKEvent
                var span: EKSpan

                if let ekEventID = calendarEvent.eventKitID,
                    let foundEvent = eventStore.event(withIdentifier: ekEventID) {
                    event = foundEvent
                    span = .futureEvents
                } else {
                    event = EKEvent(eventStore: eventStore)
                    event.calendar = calendar
                    span = .thisEvent
                }

                update(event: event, with: calendarEvent)
                try? eventStore.save(event, span: span, commit: false)
                calendarEvent.eventKitID = event.eventIdentifier
            }

            try? eventStore.commit()
            context.saveWithResult()
        }

    }

    public static func remove(events: [CalendarEvent]) throws {
        let eventsToDelete = events.compactMap {
            return $0.eventKitID
        }.compactMap {
            return eventStore.event(withIdentifier: $0)
        }

        for event in eventsToDelete {
            try eventStore.remove(event, span: EKSpan.futureEvents, commit: false)
        }

        try eventStore.commit()
    }

    public static func deleteSchulcloudCalendar() throws {
        guard let calendarIdentifier = EventKitSettings.current.calendarIdentifier,
              let calendar = eventStore.calendar(withIdentifier: calendarIdentifier) else { return }

        try eventStore.removeCalendar(calendar, commit: true)

        EventKitSettings.current.calendarIdentifier = nil
        self.calendar = nil
    }
}

// MARK: Convenience conversion
extension CalendarEvent.RecurrenceRule {
    public var ekRecurrenceRule: EKRecurrenceRule {
        let until: EKRecurrenceEnd?
        if let endDate = self.endDate {
            until = EKRecurrenceEnd(end: endDate)
        } else {
            until = nil
        }

        let rule = EKRecurrenceRule(recurrenceWith: self.frequency.ekFrequency,
                                    interval: self.interval == 0 ? 1 : self.interval,
                                    daysOfTheWeek: [self.dayOfTheWeek.ekDayOfTheWeek],
                                    daysOfTheMonth: nil,
                                    monthsOfTheYear: nil,
                                    weeksOfTheYear: nil,
                                    daysOfTheYear: nil,
                                    setPositions: nil,
                                    end: until)
        return rule
    }
}

extension CalendarEvent.RecurrenceRule.Frequency {
    public var ekFrequency: EKRecurrenceFrequency {
        switch self {
        case .daily:
            return EKRecurrenceFrequency.daily
        case .weekly:
            return EKRecurrenceFrequency.weekly
        case .monthly:
            return EKRecurrenceFrequency.monthly
        case .yearly:
            return EKRecurrenceFrequency.yearly
        }
    }
}

extension CalendarEvent.RecurrenceRule.DayOfTheWeek {
    public var ekDayOfTheWeek: EKRecurrenceDayOfWeek {
        let ekWeekday: EKWeekday = {
            switch self {
            case .monday:
                return EKWeekday.monday
            case .tuesday:
                return EKWeekday.tuesday
            case .wednesday:
                return EKWeekday.wednesday
            case .thursday:
                return EKWeekday.thursday
            case .friday:
                return EKWeekday.friday
            case .saturday:
                return EKWeekday.saturday
            case .sunday:
                return EKWeekday.sunday
            }
        }()
        return EKRecurrenceDayOfWeek(ekWeekday)
    }
}
