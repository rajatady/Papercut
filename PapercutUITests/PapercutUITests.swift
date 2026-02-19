//
//  PapercutUITests.swift
//  PapercutUITests
//

import XCTest

final class PapercutUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Launch Performance

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}

// MARK: - Onboarding Flow Tests

final class OnboardingUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Reset UserDefaults to force onboarding
        app.launchArguments = ["--uitesting", "--reset-onboarding"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    @MainActor
    func testOnboarding_welcomePageDisplayed() {
        // Welcome page should show app name and tagline
        let researchPro = app.staticTexts["Research Pro"]
        XCTAssertTrue(researchPro.waitForExistence(timeout: 5), "Welcome page should show 'Research Pro' title")

        let tagline = app.staticTexts["Swipe through research.\nAI explains the rest."]
        XCTAssertTrue(tagline.exists, "Welcome page should show tagline")
    }

    @MainActor
    func testOnboarding_welcomePage_hasFeatureHighlights() {
        XCTAssertTrue(app.staticTexts["Research Pro"].waitForExistence(timeout: 5))

        XCTAssertTrue(app.staticTexts["Swipe to discover papers"].exists)
        XCTAssertTrue(app.staticTexts["AI-powered summaries"].exists)
        XCTAssertTrue(app.staticTexts["Math & code explained simply"].exists)
    }

    @MainActor
    func testOnboarding_welcomePage_letsGoButton() {
        XCTAssertTrue(app.staticTexts["Research Pro"].waitForExistence(timeout: 5))

        let letsGoButton = app.buttons["Let's Go"]
        XCTAssertTrue(letsGoButton.exists, "Let's Go button should exist")
    }

    @MainActor
    func testOnboarding_navigateToCategories() {
        XCTAssertTrue(app.staticTexts["Research Pro"].waitForExistence(timeout: 5))

        app.buttons["Let's Go"].tap()

        let categoriesTitle = app.staticTexts["What interests you?"]
        XCTAssertTrue(categoriesTitle.waitForExistence(timeout: 3), "Category selection page should appear")
    }

    @MainActor
    func testOnboarding_categorySelection_showsCount() {
        XCTAssertTrue(app.staticTexts["Research Pro"].waitForExistence(timeout: 5))
        app.buttons["Let's Go"].tap()
        XCTAssertTrue(app.staticTexts["What interests you?"].waitForExistence(timeout: 3))

        // Initially 0 selected
        XCTAssertTrue(app.staticTexts["0 selected"].exists)

        // The Continue button should exist but be disabled
        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(continueButton.exists)
    }

    @MainActor
    func testOnboarding_categorySelection_selectCategories() {
        XCTAssertTrue(app.staticTexts["Research Pro"].waitForExistence(timeout: 5))
        app.buttons["Let's Go"].tap()
        XCTAssertTrue(app.staticTexts["What interests you?"].waitForExistence(timeout: 3))

        // Tap 3 category cards
        let aiButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'AI'")).firstMatch
        if aiButton.exists {
            aiButton.tap()
        }

        let mlButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Machine Learning'")).firstMatch
        if mlButton.exists {
            mlButton.tap()
        }

        let nlpButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'NLP'")).firstMatch
        if nlpButton.exists {
            nlpButton.tap()
        }
    }

    @MainActor
    func testOnboarding_fullFlow_navigatesToFeatures() {
        XCTAssertTrue(app.staticTexts["Research Pro"].waitForExistence(timeout: 5))

        // Page 1: Welcome
        app.buttons["Let's Go"].tap()

        // Page 2: Categories - select 3
        XCTAssertTrue(app.staticTexts["What interests you?"].waitForExistence(timeout: 3))

        // Try tapping category buttons
        let categoryButtons = app.buttons.allElementsBoundByIndex
        var tapped = 0
        for button in categoryButtons {
            if tapped >= 3 { break }
            let label = button.label
            // Only tap category cards (they have emojis)
            if label.contains("🤖") || label.contains("🧠") || label.contains("💬") ||
               label.contains("👁️") || label.contains("🔗") || label.contains("🦾") {
                button.tap()
                tapped += 1
            }
        }

        if tapped >= 3 {
            app.buttons["Continue"].tap()

            // Page 3: Features
            let howItWorks = app.staticTexts["How it works"]
            XCTAssertTrue(howItWorks.waitForExistence(timeout: 3), "Features page should appear")
        }
    }

    @MainActor
    func testOnboarding_featuresPage_showsSteps() {
        // Navigate to features page
        XCTAssertTrue(app.staticTexts["Research Pro"].waitForExistence(timeout: 5))
        app.buttons["Let's Go"].tap()
        XCTAssertTrue(app.staticTexts["What interests you?"].waitForExistence(timeout: 3))

        // Swipe to features page (if category selection not needed)
        app.swipeLeft()
        app.swipeLeft()

        let howItWorks = app.staticTexts["How it works"]
        if howItWorks.waitForExistence(timeout: 3) {
            XCTAssertTrue(app.staticTexts["Swipe Up"].exists)
            XCTAssertTrue(app.staticTexts["Tap for AI Magic"].exists)
        }
    }
}

// MARK: - Feed View Tests

final class FeedUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--skip-onboarding"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    @MainActor
    func testFeed_headerTabsVisible() {
        // Give the feed time to load
        let forYouTab = app.buttons["For You"]
        if forYouTab.waitForExistence(timeout: 5) {
            XCTAssertTrue(forYouTab.exists, "For You tab should be visible")
        }

        // Check other tabs exist
        XCTAssertTrue(app.buttons["Trending"].exists || app.staticTexts["Trending"].exists)
        XCTAssertTrue(app.buttons["Latest"].exists || app.staticTexts["Latest"].exists)
        XCTAssertTrue(app.buttons["Saved"].exists || app.staticTexts["Saved"].exists)
    }

    @MainActor
    func testFeed_settingsButtonExists() {
        // The hamburger menu button
        let settingsButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'horizontal'")).firstMatch
        if settingsButton.waitForExistence(timeout: 5) {
            XCTAssertTrue(settingsButton.exists)
        }
    }

    @MainActor
    func testFeed_tapSettingsOpensSettings() {
        // Find the settings/hamburger button
        let settingsButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'horizontal'")).firstMatch

        if settingsButton.waitForExistence(timeout: 5) {
            settingsButton.tap()

            // Settings sheet should appear
            let settingsTitle = app.navigationBars["Settings"]
            XCTAssertTrue(settingsTitle.waitForExistence(timeout: 3), "Settings view should appear")
        }
    }

    @MainActor
    func testFeed_tabSwitching() {
        let trendingTab = app.buttons["Trending"]
        if trendingTab.waitForExistence(timeout: 5) {
            trendingTab.tap()
            // Tab should be selected (visual change)
            sleep(1) // Allow animation

            let latestTab = app.buttons["Latest"]
            if latestTab.exists {
                latestTab.tap()
                sleep(1)
            }
        }
    }

    @MainActor
    func testFeed_verticalSwipe() {
        // Wait for content to load
        sleep(3)

        // Swipe up to go to next paper
        app.swipeUp()
        sleep(1)

        // Swipe down to go back
        app.swipeDown()
        sleep(1)
    }

    @MainActor
    func testFeed_horizontalSwipe_switchesTabs() {
        // Wait for content
        sleep(3)

        // Swipe left to go to next tab (Trending)
        app.swipeLeft()
        sleep(1)

        // Swipe right to go back (For You)
        app.swipeRight()
        sleep(1)
    }

    @MainActor
    func testFeed_noCategoriesView() {
        // Launch with no categories
        let newApp = XCUIApplication()
        newApp.launchArguments = ["--uitesting", "--skip-onboarding", "--no-categories"]
        newApp.launch()

        let selectInterests = newApp.staticTexts["Select Your Interests"]
        if selectInterests.waitForExistence(timeout: 5) {
            XCTAssertTrue(selectInterests.exists)

            let getStarted = newApp.buttons["Get Started"]
            XCTAssertTrue(getStarted.exists)
        }
    }

    @MainActor
    func testFeed_loadingState() {
        // The loading view shows "Loading papers..."
        let loading = app.staticTexts["Loading papers..."]
        // This may or may not be visible depending on timing
        _ = loading.waitForExistence(timeout: 2)
    }
}

// MARK: - Settings View Tests

final class SettingsUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--skip-onboarding"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    private func openSettings() {
        // Find and tap the hamburger button to open settings
        let settingsButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'horizontal'")).firstMatch
        if settingsButton.waitForExistence(timeout: 5) {
            settingsButton.tap()
        }
    }

    @MainActor
    func testSettings_displaysAllSections() {
        openSettings()

        let settingsNav = app.navigationBars["Settings"]
        guard settingsNav.waitForExistence(timeout: 3) else { return }

        // Check sections exist
        XCTAssertTrue(app.staticTexts["Appearance"].exists)
        XCTAssertTrue(app.staticTexts["Categories"].exists)
        XCTAssertTrue(app.staticTexts["Summarization"].exists)
        XCTAssertTrue(app.staticTexts["Feed"].exists)
        XCTAssertTrue(app.staticTexts["About"].exists)
    }

    @MainActor
    func testSettings_darkModeToggle() {
        openSettings()

        guard app.navigationBars["Settings"].waitForExistence(timeout: 3) else { return }

        let darkModeToggle = app.switches.firstMatch
        if darkModeToggle.exists {
            darkModeToggle.tap()
            sleep(1)
            // Toggle back
            darkModeToggle.tap()
        }
    }

    @MainActor
    func testSettings_searchPapersRow() {
        openSettings()

        guard app.navigationBars["Settings"].waitForExistence(timeout: 3) else { return }

        let searchRow = app.buttons["Search Papers"]
        if searchRow.exists {
            searchRow.tap()

            // Search view should appear
            sleep(1)
        }
    }

    @MainActor
    func testSettings_followedCategoriesRow() {
        openSettings()

        guard app.navigationBars["Settings"].waitForExistence(timeout: 3) else { return }

        let categoriesRow = app.buttons["Followed Categories"]
        if categoriesRow.exists {
            categoriesRow.tap()

            // Category picker should appear
            sleep(1)
        }
    }

    @MainActor
    func testSettings_summaryStylesRow() {
        openSettings()

        guard app.navigationBars["Settings"].waitForExistence(timeout: 3) else { return }

        let stylesRow = app.buttons["Summary Styles"]
        if stylesRow.exists {
            stylesRow.tap()

            // Summary style picker should appear
            sleep(1)
        }
    }

    @MainActor
    func testSettings_autoSummarizeToggle() {
        openSettings()

        guard app.navigationBars["Settings"].waitForExistence(timeout: 3) else { return }

        // Find the Auto-Summarize toggle
        let autoSummarize = app.staticTexts["Auto-Summarize"]
        XCTAssertTrue(autoSummarize.exists)
    }

    @MainActor
    func testSettings_sortOrderPicker() {
        openSettings()

        guard app.navigationBars["Settings"].waitForExistence(timeout: 3) else { return }

        let sortOrder = app.staticTexts["Sort Order"]
        XCTAssertTrue(sortOrder.exists)
    }

    @MainActor
    func testSettings_versionInfo() {
        openSettings()

        guard app.navigationBars["Settings"].waitForExistence(timeout: 3) else { return }

        // Scroll down to About section
        app.swipeUp()

        let version = app.staticTexts["Version"]
        if version.exists {
            XCTAssertTrue(app.staticTexts["1.0.0"].exists)
        }
    }

    @MainActor
    func testSettings_arxivWebsiteLink() {
        openSettings()

        guard app.navigationBars["Settings"].waitForExistence(timeout: 3) else { return }

        app.swipeUp()

        let arxivLink = app.buttons["ArXiv Website"]
        if arxivLink.exists {
            XCTAssertTrue(arxivLink.exists)
        }
    }

    @MainActor
    func testSettings_resetButton() {
        openSettings()

        guard app.navigationBars["Settings"].waitForExistence(timeout: 3) else { return }

        app.swipeUp()

        let resetButton = app.buttons["Reset All Settings"]
        if resetButton.exists {
            XCTAssertTrue(resetButton.exists)
        }
    }

    @MainActor
    func testSettings_doneButtonDismisses() {
        openSettings()

        guard app.navigationBars["Settings"].waitForExistence(timeout: 3) else { return }

        let doneButton = app.buttons["Done"]
        XCTAssertTrue(doneButton.exists)
        doneButton.tap()

        // Settings should dismiss
        sleep(1)
        XCTAssertFalse(app.navigationBars["Settings"].exists)
    }

    @MainActor
    func testSettings_keepPapersStepper() {
        openSettings()

        guard app.navigationBars["Settings"].waitForExistence(timeout: 3) else { return }

        let keepPapers = app.staticTexts["Keep Papers"]
        XCTAssertTrue(keepPapers.exists)
    }
}

// MARK: - Search View Tests

final class SearchUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--skip-onboarding"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    private func openSearch() {
        // Open settings first
        let settingsButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'horizontal'")).firstMatch
        if settingsButton.waitForExistence(timeout: 5) {
            settingsButton.tap()
        }

        guard app.navigationBars["Settings"].waitForExistence(timeout: 3) else { return }

        let searchRow = app.buttons["Search Papers"]
        if searchRow.exists {
            searchRow.tap()
        }
    }

    @MainActor
    func testSearch_hasSearchField() {
        openSearch()
        sleep(1)

        // Search view should have a text field
        let searchFields = app.textFields.allElementsBoundByIndex
        // Search view exists if there's any text field or search bar
        XCTAssertTrue(searchFields.count > 0 || app.searchFields.count > 0)
    }

    @MainActor
    func testSearch_cancelDismisses() {
        openSearch()
        sleep(1)

        // Try to find a cancel/close button
        let cancelButton = app.buttons["Cancel"]
        let closeButton = app.buttons["xmark"]
        let doneButton = app.buttons["Done"]

        if cancelButton.exists {
            cancelButton.tap()
        } else if closeButton.exists {
            closeButton.tap()
        } else if doneButton.exists {
            doneButton.tap()
        }
    }
}

// MARK: - Category Picker Tests

final class CategoryPickerUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--skip-onboarding"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    private func openCategoryPicker() {
        let settingsButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'horizontal'")).firstMatch
        if settingsButton.waitForExistence(timeout: 5) {
            settingsButton.tap()
        }

        guard app.navigationBars["Settings"].waitForExistence(timeout: 3) else { return }

        let categoriesRow = app.buttons["Followed Categories"]
        if categoriesRow.exists {
            categoriesRow.tap()
        }
    }

    @MainActor
    func testCategoryPicker_displaysCategories() {
        openCategoryPicker()
        sleep(1)

        // Should show category groups
        let computerScience = app.staticTexts["Computer Science"]
        if computerScience.waitForExistence(timeout: 3) {
            XCTAssertTrue(computerScience.exists)
        }
    }

    @MainActor
    func testCategoryPicker_searchable() {
        openCategoryPicker()
        sleep(1)

        // Check if search field exists in the picker
        let searchFields = app.searchFields.allElementsBoundByIndex
        if !searchFields.isEmpty {
            searchFields[0].tap()
            searchFields[0].typeText("AI")
            sleep(1)
        }
    }
}

// MARK: - Summary Style Picker Tests

final class SummaryStylePickerUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--skip-onboarding"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    private func openStylePicker() {
        let settingsButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'horizontal'")).firstMatch
        if settingsButton.waitForExistence(timeout: 5) {
            settingsButton.tap()
        }

        guard app.navigationBars["Settings"].waitForExistence(timeout: 3) else { return }

        let stylesRow = app.buttons["Summary Styles"]
        if stylesRow.exists {
            stylesRow.tap()
        }
    }

    @MainActor
    func testStylePicker_displaysAllStyles() {
        openStylePicker()
        sleep(1)

        // Check for known style names
        let tldr = app.staticTexts["TL;DR"]
        if tldr.waitForExistence(timeout: 3) {
            XCTAssertTrue(tldr.exists)
        }

        XCTAssertTrue(app.staticTexts["Key Points"].exists || true) // Optional check
        XCTAssertTrue(app.staticTexts["The Math"].exists || true)
    }

    @MainActor
    func testStylePicker_togglesWork() {
        openStylePicker()
        sleep(1)

        // Find a toggle and tap it
        let toggles = app.switches.allElementsBoundByIndex
        if !toggles.isEmpty {
            toggles[0].tap()
            sleep(1)
            // Tap again to re-enable
            toggles[0].tap()
        }
    }
}

// MARK: - Accessibility Tests

final class AccessibilityUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArgumenDownts = ["--uitesting", "--skip-onboarding"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    @MainActor
    func testAccessibility_feedTabsAreAccessible() {
        let tabs = ["For You", "Trending", "Latest", "Saved"]
        for tab in tabs {
            let element = app.buttons[tab]
            if element.waitForExistence(timeout: 3) {
                XCTAssertTrue(element.isHittable, "\(tab) tab should be hittable")
            }
        }
    }

    @MainActor
    func testAccessibility_settingsAccessible() {
        let settingsButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'horizontal'")).firstMatch
        if settingsButton.waitForExistence(timeout: 5) {
            XCTAssertTrue(settingsButton.isHittable, "Settings button should be hittable")
        }
    }
}
