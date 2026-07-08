//
//  AppleCalendarEventProvider.swift
//  Zirn
//

import EventKit
import Foundation

struct CalendarRecommendationEvent: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    let calendarTitle: String
    let location: String?
    let notes: String?
    let startDate: Date
    let endDate: Date
    let priority: CalendarRecommendationPriority

    var compactDescription: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        var parts = [
            "\(priority.displayTitle): \(title)",
            "Starts: \(formatter.string(from: startDate))",
            "Calendar: \(calendarTitle)"
        ]
        if let location, !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("Location: \(location)")
        }
        if let notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("Notes: \(String(notes.prefix(360)))")
        }
        return parts.joined(separator: "\n")
    }
}

enum CalendarRecommendationPriority: String, Codable, Equatable {
    case test
    case classSession
    case other

    var rank: Int {
        switch self {
        case .test:
            return 0
        case .classSession:
            return 1
        case .other:
            return 2
        }
    }

    var displayTitle: String {
        switch self {
        case .test:
            return "Test"
        case .classSession:
            return "Class"
        case .other:
            return "Calendar"
        }
    }
}

enum AppleCalendarEventProvider {
    private static let lookaheadDays = 21

    static func requestAccessIfNeeded() async throws {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .authorized, .fullAccess:
            return
        case .notDetermined:
            let store = EKEventStore()
            let granted: Bool
            if #available(macOS 14.0, *) {
                granted = try await store.requestFullAccessToEvents()
            } else {
                granted = try await withCheckedThrowingContinuation { continuation in
                    store.requestAccess(to: .event) { isGranted, error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: isGranted)
                        }
                    }
                }
            }
            guard granted else { throw CalendarAccessError.denied }
        case .denied, .restricted, .writeOnly:
            throw CalendarAccessError.denied
        @unknown default:
            throw CalendarAccessError.denied
        }
    }

    static func upcomingRecommendationEvents() async throws -> [CalendarRecommendationEvent] {
        try await requestAccessIfNeeded()

        let store = EKEventStore()
        let now = Date()
        let end = Calendar.current.date(byAdding: .day, value: lookaheadDays, to: now) ?? now.addingTimeInterval(21 * 24 * 60 * 60)
        let predicate = store.predicateForEvents(withStart: now, end: end, calendars: nil)

        return store.events(matching: predicate)
            .filter { $0.endDate >= now }
            .map(calendarRecommendationEvent)
            .sorted {
                if $0.priority.rank != $1.priority.rank {
                    return $0.priority.rank < $1.priority.rank
                }
                return $0.startDate < $1.startDate
            }
    }

    static func upcomingClassEvents() async throws -> [CalendarRecommendationEvent] {
        let events = try await upcomingRecommendationEvents()
        return events
            .filter { $0.priority == .classSession }
            .sorted { $0.startDate < $1.startDate }
    }

    private static func calendarRecommendationEvent(from event: EKEvent) -> CalendarRecommendationEvent {
        let title = event.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let location = event.location?.trimmingCharacters(in: .whitespacesAndNewlines)
        let notes = event.notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        let searchableText = [title, location, notes, event.calendar.title]
            .compactMap { $0 }
            .joined(separator: " ")

        return CalendarRecommendationEvent(
            id: event.eventIdentifier ?? UUID().uuidString,
            title: title?.isEmpty == false ? title! : "Untitled event",
            calendarTitle: event.calendar.title,
            location: location?.isEmpty == false ? location : nil,
            notes: notes?.isEmpty == false ? notes : nil,
            startDate: event.startDate,
            endDate: event.endDate,
            priority: priority(for: searchableText)
        )
    }

    private static func priority(for text: String) -> CalendarRecommendationPriority {
        let normalized = text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()

        let testKeywords = ["test", "exam", "quiz", "midterm", "final", "assessment"]
        if testKeywords.contains(where: { normalized.contains($0) }) {
            return .test
        }

        let classKeywords = ["class", "lecture", "lab", "seminar", "discussion", "recitation", "course"]
        if classKeywords.contains(where: { normalized.contains($0) }) {
            return .classSession
        }

        return .other
    }
}

private enum CalendarAccessError: LocalizedError {
    case denied

    var errorDescription: String? {
        switch self {
        case .denied:
            return "Enable Apple Calendar access in macOS Privacy & Security, then turn Apple Calendar Sync on again."
        }
    }
}
