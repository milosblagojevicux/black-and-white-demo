import XCTest

final class BlackAndWhiteUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSplashReferenceState() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["Life is not\nblack and white.\nThis app is."].waitForExistence(timeout: 2))
        let startButton = app.buttons["start-asking"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 2))
        XCTAssertTrue(startButton.isHittable)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Splash"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testStartAskingReachesInput() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["start-asking"].tap()

        XCTAssertTrue(app.textFields["question-input"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 2))
        let submitButton = app.buttons["submit-question"]
        XCTAssertTrue(submitButton.waitForExistence(timeout: 2))
        XCTAssertTrue(submitButton.isHittable)
        app.textFields["question-input"].typeText("Should every product have AI?")
        Thread.sleep(forTimeInterval: 0.5)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Ask focused"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testTappingOutsideFocusedAskDismissesKeyboardAndPreservesQuestion() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-motion-black"]
        app.launch()

        let input = app.textFields["question-input"]
        XCTAssertTrue(input.waitForExistence(timeout: 2))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 2))
        input.typeText("Should I keep this question?")

        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)).tap()

        let keyboardGone = expectation(
            for: NSPredicate(format: "exists == false"),
            evaluatedWith: app.keyboards.firstMatch
        )
        wait(for: [keyboardGone], timeout: 2)
        XCTAssertEqual(input.value as? String, "Should I keep this question?")

        input.tap()

        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 2))
        XCTAssertEqual(input.value as? String, "Should I keep this question?")
    }

    @MainActor
    func testBlackDecisionMotionSequence() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-motion-black"]
        app.launch()

        let input = app.textFields["question-input"]
        XCTAssertTrue(input.waitForExistence(timeout: 2))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 2))
        input.typeText("Should every product have AI?")

        // Gives an external simulator recorder a clean pre-submit hold to trim against.
        Thread.sleep(forTimeInterval: 1.5)
        app.buttons["submit-question"].tap()

        XCTAssertTrue(app.staticTexts["verdict-text"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["ask-again"].waitForExistence(timeout: 4))
        Thread.sleep(forTimeInterval: 1)
    }

    @MainActor
    func testSubmittingKeepsKeyboardAndShowsOnlySubmitLoadingControlWhileResponseIsPending() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-pending-standard"]
        app.launch()

        let input = app.textFields["question-input"]
        XCTAssertTrue(input.waitForExistence(timeout: 2))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 2))
        input.typeText("Should every product have AI?")
        app.buttons["submit-question"].tap()

        let loading = app.descendants(matching: .any)["decision-loading"]
        // This dedicated scenario never resolves during the test, so this
        // assertion verifies the pending state rather than scheduler timing.
        XCTAssertTrue(loading.waitForExistence(timeout: 2))
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        XCTAssertTrue(input.exists)
        XCTAssertFalse(app.otherElements["deciding-takeover"].exists)

        XCTAssertEqual(loading.label, "Loading decision")
        XCTAssertFalse(app.buttons["decision-loading"].exists)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Pending response with keyboard and AI-thinking mark"
        screenshot.lifetime = .keepAlways
        add(screenshot)

    }

    @MainActor
    func testLoadingMotionLabLaunchArgumentPresentsDebugLabUsingProductionMark() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--motion-lab-loading"]
        app.launch()

        XCTAssertTrue(app.otherElements["loading-motion-lab"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["loading-motion-lab-replay"].exists)
        XCTAssertTrue(app.buttons["loading-motion-lab-reset"].exists)
        XCTAssertTrue(app.buttons["loading-motion-lab-copy"].exists)
        XCTAssertFalse(app.buttons["submit-question"].exists)
    }

    @MainActor
    func testLoadingReturnsSafelyOnError() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-loading-error"]
        app.launch()

        let input = app.textFields["question-input"]
        XCTAssertTrue(input.waitForExistence(timeout: 2))
        input.typeText("Should every product have AI?")
        app.buttons["submit-question"].tap()

        let loading = app.descendants(matching: .any)["decision-loading"]
        XCTAssertTrue(loading.waitForExistence(timeout: 0.5))
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        XCTAssertTrue(app.staticTexts["Couldn't reach the judge."].waitForExistence(timeout: 2))
        XCTAssertFalse(loading.exists)

        app.buttons["try-again"].tap()
        XCTAssertTrue(app.textFields["question-input"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["submit-question"].exists)
    }

    @MainActor
    func testInstantResponseNeverPresentsDecidingTakeover() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-pending-instant"]
        app.launch()

        let input = app.textFields["question-input"]
        XCTAssertTrue(input.waitForExistence(timeout: 2))
        input.typeText("Is water wet?")
        app.buttons["submit-question"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["decision-loading"].waitForExistence(timeout: 0.5))
        XCTAssertFalse(app.otherElements["deciding-takeover"].exists)
        XCTAssertTrue(app.staticTexts["verdict-text"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.otherElements["deciding-takeover"].exists)
    }

    @MainActor
    func testFakeoutMotionDoesNotStartBeforeAuthoritativeResponse() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-pending-fakeout"]
        app.launch()

        let input = app.textFields["question-input"]
        XCTAssertTrue(input.waitForExistence(timeout: 2))
        input.typeText("Should I flip a coin?")
        app.buttons["submit-question"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["decision-loading"].waitForExistence(timeout: 0.5))
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        XCTAssertFalse(app.otherElements["verdict-animation-trace"].exists)
        XCTAssertFalse(app.otherElements["deciding-takeover"].exists)
    }

    @MainActor
    func testFakeoutDecisionExecutesLosingThenWinningTakeoverBeforeSlam() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-verdict-fakeout"]
        app.launch()

        let input = app.textFields["question-input"]
        XCTAssertTrue(input.waitForExistence(timeout: 2))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 2))
        input.typeText("Should every product have AI?")
        app.buttons["submit-question"].tap()

        XCTAssertTrue(app.staticTexts["verdict-text"].waitForExistence(timeout: 4))

        let trace = app.otherElements["verdict-animation-trace"]
        XCTAssertTrue(trace.waitForExistence(timeout: 2))
        XCTAssertEqual(
            trace.value as? String,
            "preflightDownRight>preflightUpLeft>preflightSettle>preflightDownRight>preflightUpLeft>preflightSettle>commitment>hold>reversal>preSlamPause>slam"
        )
        XCTAssertEqual(
            app.otherElements["fakeout-geometry-trace"].value as? String,
            "commitment:white:up-left>reversal:black:down-right"
        )

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Fakeout verdict completed"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testAskAgainReturnsToFocusedInputWithKeyboard() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-motion-black"]
        app.launch()

        let input = app.textFields["question-input"]
        XCTAssertTrue(input.waitForExistence(timeout: 2))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 2))
        input.typeText("Should every product have AI?")
        let submit = app.buttons["submit-question"]
        XCTAssertTrue(submit.isHittable)
        // Tap inside the slanted surface, well left of the arrow glyph.
        submit.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.75)).tap()

        let askAgain = app.buttons["ask-again"]
        XCTAssertTrue(askAgain.waitForExistence(timeout: 4))
        XCTAssertTrue(askAgain.isHittable)
        // Tap well left of the label to prove the whole visible CTA surface is actionable.
        askAgain.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.75)).tap()

        XCTAssertTrue(app.textFields["question-input"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 2))
        XCTAssertEqual(app.textFields["question-input"].value as? String, "")
        Thread.sleep(forTimeInterval: 0.8)
    }

    @MainActor
    func testUnsupportedFormatReturnsInlineWithoutVerdict() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-motion-black"]
        app.launch()

        let input = app.textFields["question-input"]
        XCTAssertTrue(input.waitForExistence(timeout: 2))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 2))
        input.typeText("Who is better, Nadal or Djokovic?")
        app.buttons["submit-question"].tap()

        let correction = app.staticTexts["ask-heading"]
        XCTAssertTrue(correction.waitForExistence(timeout: 4))
        XCTAssertEqual(
            correction.label,
            "Unsupported question format. Rephrase as a yes-or-no question."
        )
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 2))
        XCTAssertEqual(
            app.textFields["question-input"].value as? String,
            "Who is better, Nadal or Djokovic?"
        )
        XCTAssertFalse(app.staticTexts["verdict-text"].exists)
        XCTAssertFalse(app.buttons["ask-again"].exists)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Unsupported format inline correction"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testUnsupportedFormatDoesNotOfferAnAutomaticReplacement() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-unsupported-suggestion"]
        app.launch()

        let input = app.textFields["question-input"]
        XCTAssertTrue(input.waitForExistence(timeout: 2))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 2))
        input.typeText("Who is better, Nadal or Djokovic?")
        app.buttons["submit-question"].tap()

        XCTAssertEqual(
            app.textFields["question-input"].value as? String,
            "Who is better, Nadal or Djokovic?"
        )
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        XCTAssertFalse(app.staticTexts["verdict-text"].exists)
        XCTAssertFalse(app.buttons["ask-again"].exists)
        XCTAssertFalse(app.buttons["suggested-question"].exists)
    }

    @MainActor
    func testRestingAskReferenceState() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-ask-resting"]
        app.launch()

        XCTAssertTrue(app.textFields["question-input"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["ask-heading"].waitForExistence(timeout: 2))
        let submitButton = app.buttons["submit-question"]
        XCTAssertTrue(submitButton.waitForExistence(timeout: 2))
        XCTAssertTrue(submitButton.isHittable)
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        Thread.sleep(forTimeInterval: 0.5)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Ask resting"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testDecidingReferenceState() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-deciding"]
        app.launch()

        XCTAssertTrue(app.otherElements["deciding-takeover"].waitForExistence(timeout: 2))
        Thread.sleep(forTimeInterval: 0.5)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Deciding takeover"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testWhiteVerdictPrototypeState() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-verdict-white"]
        app.launch()

        XCTAssertTrue(app.staticTexts["verdict-text"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["ask-again"].waitForExistence(timeout: 4))
        Thread.sleep(forTimeInterval: 0.3)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "White verdict prototype"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testBlackVerdictPrototypeState() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-verdict-black"]
        app.launch()

        XCTAssertTrue(app.staticTexts["verdict-text"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["ask-again"].waitForExistence(timeout: 4))
        Thread.sleep(forTimeInterval: 0.3)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Black verdict prototype"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testGrayVerdictPrototypeState() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-verdict-gray"]
        app.launch()

        XCTAssertTrue(app.staticTexts["verdict-text"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["ask-again"].waitForExistence(timeout: 4))
        Thread.sleep(forTimeInterval: 0.3)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Gray verdict prototype"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testNetworkErrorPrototypeState() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-error"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Couldn't reach the judge."].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["try-again"].waitForExistence(timeout: 2))

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Network error prototype"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testServicePausedPrototypeState() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-paused"]
        app.launch()

        XCTAssertTrue(app.staticTexts["I've stopped judging for a moment."].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["try-again"].waitForExistence(timeout: 2))

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Service paused prototype"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testUsageWarningPrototypeState() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-usage-warning"]
        app.launch()

        XCTAssertTrue(app.staticTexts["verdict-text"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["usage-message"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["ask-again"].exists)
        Thread.sleep(forTimeInterval: 0.3)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Usage warning prototype"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testUsageLastPrototypeState() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-usage-last"]
        app.launch()

        XCTAssertTrue(app.staticTexts["verdict-text"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["usage-message"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["ask-again"].exists)
        Thread.sleep(forTimeInterval: 0.3)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Usage last prototype"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testUsageExhaustedPrototypeState() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-usage-exhausted"]
        app.launch()

        XCTAssertTrue(app.staticTexts["I've judged enough for today."].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Back ")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts["You're on your own until then."].exists)
        XCTAssertFalse(app.buttons["ask-again"].exists)
        XCTAssertEqual(app.buttons.count, 0)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Usage exhausted prototype"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

}
