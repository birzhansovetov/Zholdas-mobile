import Foundation

public nonisolated struct EventRestrictionTemplates: Sendable {
    public let prefix: String
    public let men: String
    public let women: String
    public let ageRange: String
    public let ageFrom: String
    public let ageTo: String

    public init(
        prefix: String,
        men: String,
        women: String,
        ageRange: String,
        ageFrom: String,
        ageTo: String
    ) {
        self.prefix = prefix
        self.men = men
        self.women = women
        self.ageRange = ageRange
        self.ageFrom = ageFrom
        self.ageTo = ageTo
    }

    @MainActor
    public static var localized: EventRestrictionTemplates {
        EventRestrictionTemplates(
            prefix: "ev_restr_prefix".localized,
            men: "ev_restr_men".localized,
            women: "ev_restr_women".localized,
            ageRange: "ev_restr_age_range".localized,
            ageFrom: "ev_restr_age_from".localized,
            ageTo: "ev_restr_age_to".localized
        )
    }
}

public nonisolated func eventRestrictionsText(
    genderFilter: String?,
    minAge: Int?,
    maxAge: Int?,
    templates: EventRestrictionTemplates
) -> String? {
    let rawGender = (genderFilter ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let genderPart: String?
    switch rawGender {
    case "male", "men":
        genderPart = templates.men
    case "female", "women":
        genderPart = templates.women
    default:
        genderPart = nil
    }

    let effectiveMin: Int? = (minAge != nil && minAge! > 0) ? minAge : nil
    let effectiveMax: Int? = (maxAge != nil && maxAge! > 0) ? maxAge : nil

    let agePart: String?
    if let min = effectiveMin, let max = effectiveMax {
        agePart = String(format: templates.ageRange, min, max)
    } else if let min = effectiveMin {
        agePart = String(format: templates.ageFrom, min)
    } else if let max = effectiveMax {
        agePart = String(format: templates.ageTo, max)
    } else {
        agePart = nil
    }

    var parts: [String] = []
    if let genderPart {
        parts.append(genderPart)
    }
    if let agePart {
        parts.append(agePart)
    }

    if parts.isEmpty {
        return nil
    }

    return templates.prefix + parts.joined(separator: " · ")
}
