//
//  QuizAppUITests.swift
//  quiz_appUITests
//
//  Test UI minimo: verifica che l'app si avvii e mostri la tab bar principale.
//

import XCTest

final class QuizAppUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchShowsMainTabs() throws {
        let app = XCUIApplication()
        app.launch()
        // Le tre tab principali devono essere presenti.
        XCTAssertTrue(app.tabBars.buttons["Quiz"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.tabBars.buttons["Materie"].exists)
        XCTAssertTrue(app.tabBars.buttons["Statistiche"].exists)
    }
}
