//
//  ZholdasTests.swift
//  ZholdasTests
//
//  Created by Birzhan Sovetov on 26.06.2026.
//

import Foundation
import Testing
@testable import Zholdas

struct ZholdasTests {

    @Test func eventDeepLinkCustomScheme() {
        // Standard scheme: zholdas://event/<id>
        let url1 = URL(string: "zholdas://event/123")!
        #expect(EventDeepLink.eventID(from: url1) == 123)

        // Trailing slash
        let url2 = URL(string: "zholdas://event/456/")!
        #expect(EventDeepLink.eventID(from: url2) == 456)

        // Plural events
        let url3 = URL(string: "zholdas://events/789")!
        #expect(EventDeepLink.eventID(from: url3) == 789)

        // Triple slash / no host
        let url4 = URL(string: "zholdas:///event/101")!
        #expect(EventDeepLink.eventID(from: url4) == 101)

        // Non-positive or invalid IDs must return nil
        #expect(EventDeepLink.eventID(from: URL(string: "zholdas://event/0")!) == nil)
        #expect(EventDeepLink.eventID(from: URL(string: "zholdas://event/-1")!) == nil)
        #expect(EventDeepLink.eventID(from: URL(string: "zholdas://event/abc")!) == nil)
        #expect(EventDeepLink.eventID(from: URL(string: "zholdas://event")!) == nil)
        #expect(EventDeepLink.eventID(from: URL(string: "zholdas://event/123/edit")!) == nil)

        // Different host or path on zholdas scheme
        #expect(EventDeepLink.eventID(from: URL(string: "zholdas://reset-password")!) == nil)
        #expect(EventDeepLink.eventID(from: URL(string: "zholdas://profile/123")!) == nil)
    }

    @Test func eventDeepLinkBackendURL() {
        let backend = URL(string: "https://zholdas-api-de89a64e4196.herokuapp.com")!

        // Matching backend host
        let url1 = URL(string: "https://zholdas-api-de89a64e4196.herokuapp.com/events/123")!
        #expect(EventDeepLink.eventID(from: url1, backendBaseURL: backend) == 123)

        // Trailing slash
        let url2 = URL(string: "https://zholdas-api-de89a64e4196.herokuapp.com/events/456/")!
        #expect(EventDeepLink.eventID(from: url2, backendBaseURL: backend) == 456)

        // Singular event
        let url3 = URL(string: "https://zholdas-api-de89a64e4196.herokuapp.com/event/789")!
        #expect(EventDeepLink.eventID(from: url3, backendBaseURL: backend) == 789)

        // Non-positive or invalid IDs
        #expect(EventDeepLink.eventID(from: URL(string: "https://zholdas-api-de89a64e4196.herokuapp.com/events/0")!, backendBaseURL: backend) == nil)
        #expect(EventDeepLink.eventID(from: URL(string: "https://zholdas-api-de89a64e4196.herokuapp.com/events/-10")!, backendBaseURL: backend) == nil)
        #expect(EventDeepLink.eventID(from: URL(string: "https://zholdas-api-de89a64e4196.herokuapp.com/events/invalid")!, backendBaseURL: backend) == nil)
        #expect(EventDeepLink.eventID(from: URL(string: "https://zholdas-api-de89a64e4196.herokuapp.com/events")!, backendBaseURL: backend) == nil)
        #expect(EventDeepLink.eventID(from: URL(string: "https://zholdas-api-de89a64e4196.herokuapp.com/users/123")!, backendBaseURL: backend) == nil)

        // Mismatched host must return nil
        let otherURL = URL(string: "https://example.com/events/123")!
        #expect(EventDeepLink.eventID(from: otherURL, backendBaseURL: backend) == nil)

        // Localhost backend
        let localBackend = URL(string: "http://localhost:8080")!
        let localURL = URL(string: "http://localhost:8080/events/42")!
        #expect(EventDeepLink.eventID(from: localURL, backendBaseURL: localBackend) == 42)
    }

    @Test func eventDeepLinkWebURLs() {
        // Standard web URLs: https://www.zholdas.app/e/<id>
        let url1 = URL(string: "https://www.zholdas.app/e/123")!
        #expect(EventDeepLink.eventID(from: url1) == 123)

        // Trailing slash
        let url2 = URL(string: "https://www.zholdas.app/e/456/")!
        #expect(EventDeepLink.eventID(from: url2) == 456)

        // Non-www host (zholdas.app)
        let url3 = URL(string: "https://zholdas.app/e/789")!
        #expect(EventDeepLink.eventID(from: url3) == 789)

        // http scheme
        let url4 = URL(string: "http://zholdas.app/e/101")!
        #expect(EventDeepLink.eventID(from: url4) == 101)

        // Path /events/<id>
        let url5 = URL(string: "https://www.zholdas.app/events/202")!
        #expect(EventDeepLink.eventID(from: url5) == 202)

        // Query parameters
        let url6 = URL(string: "https://www.zholdas.app/e/303?utm_source=telegram&ref=share")!
        #expect(EventDeepLink.eventID(from: url6) == 303)

        // Query parameters with trailing slash
        let url7 = URL(string: "https://zholdas.app/e/404/?preview=true")!
        #expect(EventDeepLink.eventID(from: url7) == 404)

        // webURL generator
        let generatedURL = EventDeepLink.webURL(for: 555)
        #expect(generatedURL.absoluteString == "https://www.zholdas.app/e/555")
        #expect(EventDeepLink.eventID(from: generatedURL) == 555)

        let generatedURL32 = EventDeepLink.webURL(for: Int32(777))
        #expect(generatedURL32.absoluteString == "https://www.zholdas.app/e/777")
        #expect(EventDeepLink.eventID(from: generatedURL32) == 777)

        // Invalid or non-positive IDs
        #expect(EventDeepLink.eventID(from: URL(string: "https://www.zholdas.app/e/0")!) == nil)
        #expect(EventDeepLink.eventID(from: URL(string: "https://www.zholdas.app/e/-10")!) == nil)
        #expect(EventDeepLink.eventID(from: URL(string: "https://www.zholdas.app/e/abc")!) == nil)
        #expect(EventDeepLink.eventID(from: URL(string: "https://www.zholdas.app/e")!) == nil)
        #expect(EventDeepLink.eventID(from: URL(string: "https://www.zholdas.app/e/123/edit")!) == nil)

        // Other hosts or paths
        #expect(EventDeepLink.eventID(from: URL(string: "https://example.com/e/123")!) == nil)
        #expect(EventDeepLink.eventID(from: URL(string: "https://www.zholdas.app/users/123")!) == nil)
    }

    @Test func eventRestrictions() {
        let templates = EventRestrictionTemplates(
            prefix: "Restrictions: ",
            men: "Men only",
            women: "Women only",
            ageRange: "Ages %1$d–%2$d",
            ageFrom: "Ages %d+",
            ageTo: "Up to age %d"
        )

        // Без ограничений → nil
        #expect(eventRestrictionsText(genderFilter: nil, minAge: nil, maxAge: nil, templates: templates) == nil)
        #expect(eventRestrictionsText(genderFilter: "all", minAge: nil, maxAge: nil, templates: templates) == nil)
        #expect(eventRestrictionsText(genderFilter: "", minAge: nil, maxAge: nil, templates: templates) == nil)

        // Только пол
        #expect(eventRestrictionsText(genderFilter: "male", minAge: nil, maxAge: nil, templates: templates) == "Restrictions: Men only")
        #expect(eventRestrictionsText(genderFilter: "female", minAge: nil, maxAge: nil, templates: templates) == "Restrictions: Women only")

        // Только min
        #expect(eventRestrictionsText(genderFilter: nil, minAge: 18, maxAge: nil, templates: templates) == "Restrictions: Ages 18+")

        // Только max
        #expect(eventRestrictionsText(genderFilter: nil, minAge: nil, maxAge: 30, templates: templates) == "Restrictions: Up to age 30")

        // Оба (min и max)
        #expect(eventRestrictionsText(genderFilter: nil, minAge: 18, maxAge: 30, templates: templates) == "Restrictions: Ages 18–30")

        // Пол + возраст
        #expect(eventRestrictionsText(genderFilter: "male", minAge: 18, maxAge: 30, templates: templates) == "Restrictions: Men only · Ages 18–30")
        #expect(eventRestrictionsText(genderFilter: "female", minAge: 21, maxAge: nil, templates: templates) == "Restrictions: Women only · Ages 21+")

        // 0 = не задано
        #expect(eventRestrictionsText(genderFilter: nil, minAge: 0, maxAge: 0, templates: templates) == nil)
        #expect(eventRestrictionsText(genderFilter: "all", minAge: 0, maxAge: nil, templates: templates) == nil)
        #expect(eventRestrictionsText(genderFilter: "female", minAge: 0, maxAge: 25, templates: templates) == "Restrictions: Women only · Up to age 25")
        #expect(eventRestrictionsText(genderFilter: "male", minAge: 18, maxAge: 0, templates: templates) == "Restrictions: Men only · Ages 18+")
    }

}
