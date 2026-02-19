//
//  PapercutUITestsLaunchTests.swift
//  PapercutUITests
//

import XCTest

final class PapercutUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testLaunch_captureOnboarding() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-onboarding"]
        app.launch()

        // Wait for onboarding to appear
        sleep(2)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Onboarding Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testLaunch_captureFeed() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--skip-onboarding"]
        app.launch()

        // Wait for feed to load
        sleep(3)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Feed Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testLaunch_captureSettings() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--skip-onboarding"]
        app.launch()

        // Open settings
        let settingsButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'horizontal'")).firstMatch
        if settingsButton.waitForExistence(timeout: 5) {
            settingsButton.tap()
            sleep(1)
        }

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Settings Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testLaunch_captureDarkMode() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--skip-onboarding", "--dark-mode"]
        app.launch()

        sleep(2)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Dark Mode Feed"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
