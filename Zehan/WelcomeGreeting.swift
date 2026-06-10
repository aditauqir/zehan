//
//  WelcomeGreeting.swift
//  Zirn
//

import Foundation

enum WelcomeGreeting {
    static func message(for date: Date = Date(), userName: String) -> String {
        let trimmedName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmedName.isEmpty ? "there" : trimmedName
        let hour = Calendar.current.component(.hour, from: date)

        let leadIn: String
        switch hour {
        case 5..<12:
            leadIn = "Having a coffee?"
        case 12..<17:
            leadIn = "Good afternoon."
        case 17..<21:
            leadIn = "Good evening."
        default:
            leadIn = "Burning the midnight oil?"
        }

        return "\(leadIn) Welcome, \(name)."
    }
}

enum AppFont {
    static let ptSerifRegular = "PTSerif-Regular"
    static let ptSerifItalic = "PTSerif-Italic"
    static let welcomeGreetingSize: CGFloat = 38
}
