//
//  PapercutUITestsLaunchTests.swift
//  PapercutUITests
//

import XCTest

final class PapercutScreenshotTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        false
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func saveScreenshot(_ app: XCUIApplication, name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Onboarding Screenshots

    @MainActor
    func test01_OnboardingWelcome() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-onboarding", "--light-mode"]
        app.launch()

        // Wait for onboarding animation to settle
        sleep(3)

        saveScreenshot(app, name: "01_onboarding_welcome")
    }

    @MainActor
    func test02_OnboardingCategories() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-onboarding", "--light-mode"]
        app.launch()

        sleep(2)

        // Swipe to category selection page
        app.swipeLeft()
        sleep(2)

        // Select some categories by tapping
        let aiButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'AI'")).firstMatch
        if aiButton.waitForExistence(timeout: 3) { aiButton.tap() }

        let mlButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Machine Learning'")).firstMatch
        if mlButton.waitForExistence(timeout: 2) { mlButton.tap() }

        let nlpButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Language'")).firstMatch
        if nlpButton.waitForExistence(timeout: 2) { nlpButton.tap() }

        let cvButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Computer Vision'")).firstMatch
        if cvButton.waitForExistence(timeout: 2) { cvButton.tap() }

        sleep(1)

        saveScreenshot(app, name: "02_onboarding_categories")
    }

    // MARK: - Feed Screenshots (Light Mode)

    @MainActor
    func test03_FeedLight() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--skip-onboarding", "--light-mode"]
        app.launch()

        // Wait for feed to load papers from arXiv
        sleep(6)

        saveScreenshot(app, name: "03_feed_light")
    }

    @MainActor
    func test04_FeedDark() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--skip-onboarding", "--dark-mode"]
        app.launch()

        sleep(6)

        saveScreenshot(app, name: "04_feed_dark")
    }

    // MARK: - Search Screenshot

    @MainActor
    func test05_Search() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--skip-onboarding", "--light-mode"]
        app.launch()

        sleep(4)

        // Tap search button (magnifying glass in top-right)
        let searchButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'magnifyingglass' OR label CONTAINS[c] 'Search'")).firstMatch
        if searchButton.waitForExistence(timeout: 5) {
            searchButton.tap()
            sleep(1)
        }

        // Type a search query
        let searchField = app.searchFields.firstMatch
        if searchField.waitForExistence(timeout: 3) {
            searchField.tap()
            searchField.typeText("transformer attention mechanism")
            sleep(1)

            // Submit search
            app.keyboards.buttons["Search"].tap()
            sleep(4)
        }

        saveScreenshot(app, name: "05_search")
    }

    // MARK: - Saved Tab Screenshot

    @MainActor
    func test06_SavedTab() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--skip-onboarding", "--light-mode"]
        app.launch()

        sleep(5)

        // Bookmark current paper first
        let bookmarkButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Save' OR label CONTAINS[c] 'bookmark'")).firstMatch
        if bookmarkButton.waitForExistence(timeout: 3) {
            bookmarkButton.tap()
            sleep(1)
        }

        // Swipe to see next paper and bookmark it too
        app.swipeUp()
        sleep(2)
        if bookmarkButton.waitForExistence(timeout: 3) {
            bookmarkButton.tap()
            sleep(1)
        }

        // Switch to Saved tab
        let savedTab = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Saved'")).firstMatch
        if savedTab.waitForExistence(timeout: 3) {
            savedTab.tap()
            sleep(2)
        }

        saveScreenshot(app, name: "06_saved")
    }

    // MARK: - Trending Tab Screenshot

    @MainActor
    func test07_Trending() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--skip-onboarding", "--light-mode"]
        app.launch()

        sleep(4)

        // Switch to Trending tab
        let trendingTab = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Trending'")).firstMatch
        if trendingTab.waitForExistence(timeout: 3) {
            trendingTab.tap()
            sleep(5)
        }

        saveScreenshot(app, name: "07_trending")
    }

    // MARK: - Settings Screenshot

    @MainActor
    func test08_Settings() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--skip-onboarding", "--light-mode"]
        app.launch()

        sleep(3)

        // Tap settings button (gear icon in top-right)
        let settingsButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'gearshape' OR label CONTAINS[c] 'Settings'")).firstMatch
        if settingsButton.waitForExistence(timeout: 5) {
            settingsButton.tap()
            sleep(2)
        }

        saveScreenshot(app, name: "08_settings")
    }
}
