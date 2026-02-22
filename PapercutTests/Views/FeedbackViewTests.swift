//
//  FeedbackViewTests.swift
//  PapercutTests
//

import Testing
import Foundation
@testable import Papercut

@Suite struct FeedbackViewTests {

    @Test func bugReportURL_isValid() {
        let url = FeedbackURLs.bugReportURL
        #expect(URL(string: url) != nil)
        #expect(url.contains("github.com"))
        #expect(url.contains("labels=bug"))
    }

    @Test func featureRequestURL_isValid() {
        let url = FeedbackURLs.featureRequestURL
        #expect(URL(string: url) != nil)
        #expect(url.contains("github.com"))
        #expect(url.contains("labels=enhancement"))
    }

    @Test func bugReportURL_containsDeviceInfo() {
        let url = FeedbackURLs.bugReportURL
        #expect(url.contains("Device"))
        #expect(url.contains("iOS"))
    }

    @Test func featureRequestURL_containsPromptFields() {
        let url = FeedbackURLs.featureRequestURL
        #expect(url.contains("What"))
    }
}
