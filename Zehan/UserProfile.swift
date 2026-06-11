//
//  UserProfile.swift
//  Zirn
//

import Foundation

struct UserProfile: Codable, Equatable {
    var firstName: String = ""
    var lastName: String = ""
    var pronouns: String = ""
    var occupation: UserOccupation?

    var greetingName: String {
        let first = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let last = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !first.isEmpty, !last.isEmpty {
            return "\(first) \(last)"
        }
        if !first.isEmpty {
            return first
        }
        if !last.isEmpty {
            return last
        }
        return ""
    }

    var hasPersonalizationContext: Bool {
        !greetingName.isEmpty
            || !pronouns.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || occupation?.llmPersonalizationPrompt != nil
    }

    func personalizationContext() -> String {
        var lines: [String] = []

        let name = greetingName
        if !name.isEmpty {
            lines.append("Preferred name: \(name)")
        }

        let cleanPronouns = pronouns.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanPronouns.isEmpty {
            lines.append("Pronouns: \(cleanPronouns). Use these pronouns when referring to the user.")
        }

        if let occupationPrompt = occupation?.llmPersonalizationPrompt {
            lines.append(occupationPrompt)
        }

        guard !lines.isEmpty else { return "" }
        return lines.joined(separator: "\n")
    }
}

enum UserOccupation: Codable, Equatable, CaseIterable, Identifiable {
    case student
    case educator
    case researcher
    case preferNotToAnswer
    case other(String)

    var id: String {
        switch self {
        case .student:
            return "student"
        case .educator:
            return "educator"
        case .researcher:
            return "researcher"
        case .preferNotToAnswer:
            return "preferNotToAnswer"
        case .other(let text):
            return "other-\(text)"
        }
    }

    static var allCases: [UserOccupation] {
        [.student, .educator, .researcher, .preferNotToAnswer, .other("")]
    }

    var title: String {
        switch self {
        case .student:
            return "Student"
        case .educator:
            return "Educator"
        case .researcher:
            return "Researcher"
        case .preferNotToAnswer:
            return "Don't want to answer"
        case .other:
            return "Other"
        }
    }

    var llmPersonalizationPrompt: String? {
        switch self {
        case .student:
            return """
            Occupation context: The user is a student. Prefer clear explanations, learning-oriented framing, \
            and connect ideas to study, coursework, and skill-building when relevant. Avoid unnecessary jargon \
            unless the user already uses it.
            """
        case .educator:
            return """
            Occupation context: The user is an educator. Prefer structured explanations, teaching clarity, \
            and practical classroom, curriculum, or instructional applications when relevant.
            """
        case .researcher:
            return """
            Occupation context: The user is a researcher. Prefer precision, evidence-aware reasoning, \
            methodological clarity, and rigorous terminology when relevant.
            """
        case .preferNotToAnswer:
            return nil
        case .other(let specified):
            let clean = specified.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty else { return nil }
            return """
            Occupation context: The user describes their occupation as "\(clean)". Tailor tone, examples, \
            and depth to that role when relevant.
            """
        }
    }

    enum CodingKeys: String, CodingKey {
        case kind
        case specified
    }

    enum Kind: String, Codable {
        case student
        case educator
        case researcher
        case preferNotToAnswer
        case other
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .student:
            self = .student
        case .educator:
            self = .educator
        case .researcher:
            self = .researcher
        case .preferNotToAnswer:
            self = .preferNotToAnswer
        case .other:
            self = .other(try container.decodeIfPresent(String.self, forKey: .specified) ?? "")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .student:
            try container.encode(Kind.student, forKey: .kind)
        case .educator:
            try container.encode(Kind.educator, forKey: .kind)
        case .researcher:
            try container.encode(Kind.researcher, forKey: .kind)
        case .preferNotToAnswer:
            try container.encode(Kind.preferNotToAnswer, forKey: .kind)
        case .other(let specified):
            try container.encode(Kind.other, forKey: .kind)
            try container.encode(specified, forKey: .specified)
        }
    }
}

enum UserOccupationPickerChoice: String, CaseIterable, Identifiable {
    case none
    case student
    case educator
    case researcher
    case preferNotToAnswer
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none:
            return "Not specified"
        case .student:
            return "Student"
        case .educator:
            return "Educator"
        case .researcher:
            return "Researcher"
        case .preferNotToAnswer:
            return "Don't want to answer"
        case .other:
            return "Other"
        }
    }

    init(occupation: UserOccupation?) {
        switch occupation {
        case .none:
            self = .none
        case .student:
            self = .student
        case .educator:
            self = .educator
        case .researcher:
            self = .researcher
        case .preferNotToAnswer:
            self = .preferNotToAnswer
        case .other:
            self = .other
        }
    }

    func resolvedOccupation(otherText: String) -> UserOccupation? {
        switch self {
        case .none:
            return nil
        case .student:
            return .student
        case .educator:
            return .educator
        case .researcher:
            return .researcher
        case .preferNotToAnswer:
            return .preferNotToAnswer
        case .other:
            let clean = otherText.trimmingCharacters(in: .whitespacesAndNewlines)
            return clean.isEmpty ? nil : .other(clean)
        }
    }

    static func otherText(from occupation: UserOccupation?) -> String {
        guard case .other(let text) = occupation else { return "" }
        return text
    }
}
