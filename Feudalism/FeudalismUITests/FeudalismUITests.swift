import XCTest

final class FeudalismUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSoloEnterAndExit() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-skipIntro")
        app.launch()

        let soloButton = app.buttons["menu_solo"]
        XCTAssertTrue(soloButton.waitForExistence(timeout: 3), "Glavni izbornik s gumbom Solo treba biti vidljiv")
        soloButton.tap()

        let nazadButton = app.buttons["solo_nazad"]
        XCTAssertTrue(nazadButton.waitForExistence(timeout: 3), "Solo setup ekran s gumbom Nazad treba biti vidljiv")
        nazadButton.tap()

        XCTAssertTrue(soloButton.waitForExistence(timeout: 2), "Nakon Nazad treba biti ponovno na glavnom izborniku")
    }

    @MainActor
    func testSoloBuilderEmptyMaps() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-skipIntro")
        app.launch()

        let soloButton = app.buttons["menu_solo"]
        XCTAssertTrue(soloButton.waitForExistence(timeout: 3))
        soloButton.tap()

        let nazadButton = app.buttons["solo_nazad"]
        XCTAssertTrue(nazadButton.waitForExistence(timeout: 3))

        for side in [200, 400, 600, 800, 1000] {
            XCTAssertTrue(app.buttons["solo_empty_map_\(side)"].waitForExistence(timeout: 1))
        }

        nazadButton.tap()
        XCTAssertTrue(soloButton.waitForExistence(timeout: 2))
    }
}
