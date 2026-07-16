//
//  WelcomeGreeting.swift
//  Zirn
//

import Foundation
import SwiftUI

enum WelcomeGreeting {
    struct Parts: Equatable {
        let leadIn: String
        let welcome: String

        var full: String { "\(leadIn) \(welcome)" }
    }

    /// Soft green used for the time-of-day lead-in on the splash screen.
    static let leadInColor = Color(red: 0.52, green: 0.78, blue: 0.56)

    static func parts(for date: Date = Date(), userName: String) -> Parts {
        let trimmedName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmedName.isEmpty ? "there" : trimmedName
        let hour = Calendar.current.component(.hour, from: date)
        let pool = leadIns(forHour: hour)
        let leadIn = pool[stableIndex(for: date, hour: hour, count: pool.count)]
        return Parts(leadIn: leadIn, welcome: "Welcome, \(name).")
    }

    static func message(for date: Date = Date(), userName: String) -> String {
        parts(for: date, userName: userName).full
    }

    private static func leadIns(forHour hour: Int) -> [String] {
        switch hour {
        case 5..<12:
            return [
                "Having a coffee?",
                "Fresh page, fresh mind.",
                "Morning's quiet — good writing weather.",
                "Ease in. The vault can wait a breath.",
                "Sun's up. What's worth capturing?",
                "A clear morning suits a clear note.",
                "Warm cup, open file — classic start.",
                "Good morning. Pick up where curiosity left off.",
                "Soft light, sharp thoughts?",
                "The day's still blank. Nice.",
                "Stretch, sip, then one clean sentence.",
                "Morning focus hits different in Zirn.",
            ]
        case 12..<17:
            return [
                "Good afternoon.",
                "Midday check-in — what's still open?",
                "Afternoon light. Keep it steady.",
                "Halfway through — tidy one thread.",
                "Back at it. One note at a time.",
                "Let the afternoon earn a clean paragraph.",
                "Momentum beats perfection right now.",
                "Good afternoon. Resume without the rush.",
                "Sun's high — ideas travel farther.",
                "A short note now saves a long evening.",
                "Afternoon quiet can be productive quiet.",
                "Pick a page. Make it clearer than lunch.",
            ]
        case 17..<21:
            return [
                "Good evening.",
                "Evening desk mode — soft and focused.",
                "Wind down, or write one last clean thought.",
                "Golden hour for unfinished ideas.",
                "Evening suits reflection. Capture it.",
                "Good evening. Close loops gently.",
                "The day's noise fades — keep the signal.",
                "Lamp on, vault open. Nice rhythm.",
                "Twilight is good for honest notes.",
                "One evening sentence can settle the day.",
                "Ease into the page — no hurry.",
                "Good evening. Leave tomorrow a clearer trail.",
            ]
        default:
            return [
                "Burning the midnight oil?",
                "Late hours, clear thoughts.",
                "Night desk — keep it kind to yourself.",
                "Quiet hours are good thinking hours.",
                "The vault doesn't sleep. You can, soon.",
                "Midnight clarity hits different.",
                "One late note, then rest.",
                "Stars out. Ideas still welcome.",
                "Night writing — fewer interruptions.",
                "Soft focus, late light, honest words.",
                "If you're here, make it count — then sleep.",
                "Quiet night. Perfect for a careful edit.",
            ]
        }
    }

    /// Stable within a given hour-of-day so relaunches don't flicker, but rotates across days/hours.
    private static func stableIndex(for date: Date, hour: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let day = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 0
        let year = Calendar.current.component(.year, from: date)
        return abs(day &* 31 &+ hour &* 17 &+ year &* 3) % count
    }
}

enum AppFont {
    static let ptSerifRegular = "PTSerif-Regular"
    static let ptSerifItalic = "PTSerif-Italic"
    static let welcomeGreetingSize: CGFloat = 38
    static let chatBrandTitleSize: CGFloat = 40
    static let chatHeaderTitleSize: CGFloat = 34
}
