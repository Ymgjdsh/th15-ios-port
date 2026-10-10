import XCTest
final class Verify: XCTestCase {
    var app: XCUIApplication!
    var state: XCUIElement { app.staticTexts["th15.state"] }
    func wait(_ text: String, timeout: TimeInterval = 180) {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: state)], timeout: timeout), .completed, state.label)
    }
    func field(_ name: String) -> Int {
        for word in state.label.split(separator: " ") {
            if word.hasPrefix(name + "=") { return Int(word.split(separator: "=")[1]) ?? -1 }
        }
        return -1
    }
    func image(_ name: String) {
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = name; capture.lifetime = .keepAlways; add(capture)
    }
    func move(_ dx: CGFloat, _ dy: CGFloat) {
        let stick = app.otherElements["th15.joystick"]
        let center = stick.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        center.press(forDuration: 0.05, thenDragTo: center.withOffset(CGVector(dx: dx, dy: dy)), withVelocity: .fast, thenHoldForDuration: 0.08)
    }
    func select(_ cursor: Int) {
        for _ in 0..<12 {
            if field("cursor") == cursor { return }
            let previous = field("cursor")
            move(0, 90)
            let change = NSPredicate(format: "NOT (label CONTAINS %@)", "cursor=\(previous) ")
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: change, object: state)], timeout: 60), .completed)
        }
        XCTFail("Cursor did not reach \(cursor): \(state.label)")
    }
    func launch(_ arguments: [String]) {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication(bundleIdentifier: "org.th15.native")
        app.launchArguments = ["--ui-test"] + arguments
        app.launch()
        XCTAssertTrue(state.waitForExistence(timeout: 90))
    }
    func testControlsSettingsAndRotation() {
        launch(["--stage", "1"])
        wait("width=768 height=1024")
        XCTAssertTrue(app.otherElements["th15.joystick"].exists)
        image("TH15-portrait-fullscreen")
        let stick = app.otherElements["th15.joystick"]
        let center = stick.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        center.press(forDuration: 0.05, thenDragTo: center.withOffset(CGVector(dx: 240, dy: 0)), withVelocity: .fast, thenHoldForDuration: 1)
        app.buttons["th15.settings"].tap()
        XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout: 30))
        let deadZone = app.sliders["deadZone"]
        deadZone.adjust(toNormalizedSliderPosition: 0.8)
        let saved = deadZone.value as? String
        app.sliders["sensitivity"].adjust(toNormalizedSliderPosition: 0.7)
        image("TH15-settings")
        app.navigationBars["设置"].buttons.element(boundBy: 0).tap()
        wait("deadZone=0.40")
        XCUIDevice.shared.orientation = .landscapeLeft
        wait("width=1024 height=768")
        image("TH15-landscape-fullscreen")
        XCUIDevice.shared.orientation = .portrait
        wait("width=768 height=1024")
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["th15.settings"].waitForExistence(timeout: 60))
        app.buttons["th15.settings"].tap()
        XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout: 30))
        XCTAssertEqual(app.sliders["deadZone"].value as? String, saved)
        app.navigationBars["设置"].buttons.element(boundBy: 0).tap()
        app.terminate()
    }
    func testMenus() {
        launch([])
        wait("scene=0 screen=1 sub=2")
        for (cursor, screen) in [(3,12),(4,11),(5,14),(7,17)] {
            select(cursor); app.buttons["th15.fire"].tap()
            wait("scene=0 screen=\(screen) sub=\(screen == 17 ? 1 : 2)")
            image("TH15-menu-\(screen)")
            app.buttons["th15.bomb"].tap()
            wait("scene=0 screen=1 sub=2")
        }
        select(6); app.buttons["th15.fire"].tap()
        wait("scene=0 screen=3 sub=2")
        let music = field("music")
        move(-90,0)
        let changed = NSPredicate(format: "NOT (label CONTAINS %@)", "music=\(music) ")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: changed, object: state)], timeout: 60), .completed)
        select(2); app.buttons["th15.fire"].tap()
        wait("scene=0 screen=4 sub=2")
        app.buttons["th15.slow"].tap()
        select(5); app.buttons["th15.fire"].tap()
        wait("scene=0 screen=3 sub=2")
        wait("binding=2 ")
        app.buttons["th15.bomb"].tap(); wait("cursor=4 ")
        app.buttons["th15.bomb"].tap(); wait("scene=0 screen=1 sub=2")
        select(0); app.buttons["th15.fire"].tap()
        wait("scene=0 screen=5 sub=2")
        app.buttons["th15.fire"].tap(); wait("scene=0 screen=6 sub=2")
        app.buttons["th15.fire"].tap(); wait("scene=0 screen=7 sub=2")
        image("TH15-character-menu")
        app.buttons["th15.bomb"].tap(); wait("scene=0 screen=6 ")
        app.terminate()
    }
    func reveal(_ element: XCUIElement) {
        for _ in 0..<6 {
            if element.isHittable { return }
            app.tables.firstMatch.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }
    func testDeveloperDragAndUnlock() {
        launch(["--stage", "1"])
        app.buttons["th15.settings"].tap()
        XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout: 30))
        let limited = app.switches["dragLimited"]
        if limited.value as? String == "1" { limited.tap() }
        let developer = app.switches["developer"]
        reveal(developer)
        if developer.value as? String == "0" { developer.tap() }
        image("TH15-developer-settings")
        app.navigationBars["设置"].buttons.element(boundBy: 0).tap()
        wait("dragLimited=0"); wait("dev=1 ")
        XCTAssertTrue(app.buttons["th15.developer"].isHittable)
        app.buttons["th15.developer"].tap()
        XCTAssertTrue(app.navigationBars["开发者功能"].waitForExistence(timeout: 30))
        app.switches["th15.dev.invincible"].tap()
        app.cells["th15.dev.action.5"].tap()
        app.cells["th15.dev.action.6"].tap()
        image("TH15-developer-panel")
        app.navigationBars["开发者功能"].buttons.element(boundBy: 0).tap()
        wait("invincible=1 "); wait("score=999999999 ")
        wait("power=400 lives=8 bombs=8 ")
        app.terminate(); app.launch()
        XCTAssertTrue(state.waitForExistence(timeout: 90))
        wait("dragLimited=0"); wait("dev=1 "); wait("invincible=0 ")
        app.buttons["th15.settings"].tap()
        XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout: 30))
        app.switches["dragLimited"].tap()
        reveal(app.switches["developer"]); app.switches["developer"].tap()
        let unlock = app.cells["unlockCode"]
        reveal(unlock); unlock.tap()
        let code = app.textFields["th15.unlock.input"]
        XCTAssertTrue(code.waitForExistence(timeout: 30)); code.tap(); code.typeText("wrong")
        XCTAssertEqual(code.value as? String, "wrong")
        app.alerts.buttons["确认解锁"].tap()
        XCTAssertTrue(app.alerts["作弊码不正确"].waitForExistence(timeout: 30))
        app.alerts.buttons["好"].tap()
        unlock.tap(); XCTAssertTrue(code.waitForExistence(timeout: 30)); code.tap(); code.typeText("ymgjdsh")
        image("TH15-unlock-input"); XCTAssertEqual(code.value as? String, "ymgjdsh")
        app.alerts.buttons["确认解锁"].tap()
        XCTAssertTrue(app.alerts["解锁成功"].waitForExistence(timeout: 30))
        image("TH15-unlock-success"); app.alerts.buttons["好"].tap()
        app.navigationBars["设置"].buttons.element(boundBy: 0).tap()
        wait("musicMask=1048575 extra=1"); wait("dragLimited=1"); wait("dev=0 ")
        XCTAssertFalse(app.buttons["th15.developer"].isHittable)
        app.terminate(); app.launchArguments = ["--ui-test"]; app.launch()
        XCTAssertTrue(state.waitForExistence(timeout: 90))
        wait("scene=0 screen=1 sub=2"); wait("musicMask=1048575 extra=1")
        select(1); app.buttons["th15.fire"].tap(); wait("scene=0 screen=6 sub=2")
        app.buttons["th15.fire"].tap(); wait("scene=0 screen=7 sub=2")
        image("TH15-extra-unlocked")
        app.terminate()
    }
    func setSwitch(_ name: String, _ enabled: Bool) {
        let control = app.switches[name]; reveal(control)
        if (control.value as? String == "1") != enabled { control.tap() }
    }
    func openSettings() {
        app.buttons["th15.settings"].tap()
        XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout: 30))
    }
    func closeSettings() { app.navigationBars["设置"].buttons.element(boundBy: 0).tap() }
    func editLayout() {
        openSettings(); let row = app.cells["layout"]; reveal(row); row.tap()
        XCTAssertTrue(app.buttons["th15.layout.save"].waitForExistence(timeout: 30))
    }
    func dragControl(_ control: XCUIElement, _ dx: CGFloat, _ dy: CGFloat) {
        let center = control.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        center.press(forDuration: 0.15, thenDragTo: center.withOffset(CGVector(dx: dx, dy: dy)))
    }
    func assertCenter(_ element: XCUIElement, _ frame: CGRect) {
        XCTAssertEqual(element.frame.midX, frame.midX, accuracy: 3)
        XCTAssertEqual(element.frame.midY, frame.midY, accuracy: 3)
    }
    func testAutoBombTogglesAndLayout() {
        launch(["--stage", "1"]); wait("width=768 height=1024")
        openSettings(); setSwitch("autoFire", false); setSwitch("autoSlow", false)
        setSwitch("autoBomb", true); setSwitch("toggleFire", true); setSwitch("toggleSlow", true)
        closeSettings(); wait("autoBomb=1 "); wait("context=1 ", timeout:60); wait("pause=0 ", timeout:60)
        let fire = app.buttons["th15.fire"], slow = app.buttons["th15.slow"]
        fire.tap(); wait("fireLatch=1 "); fire.tap(); wait("fireLatch=0 ")
        slow.tap(); wait("slowLatch=1 "); slow.tap(); wait("slowLatch=0 ")
        fire.tap(); wait("fireLatch=1 "); openSettings(); closeSettings(); wait("fireLatch=0 ")
        editLayout()
        let original = fire.frame, originalStick = app.otherElements["th15.joystick"].frame
        dragControl(fire,-170,-130); dragControl(app.otherElements["th15.joystick"],130,-150)
        let portrait = fire.frame, portraitStick = app.otherElements["th15.joystick"].frame
        XCTAssertLessThan(portrait.midX, original.midX - 100)
        XCTAssertGreaterThan(portraitStick.midX, originalStick.midX + 100)
        image("TH15-layout-portrait-editor")
        app.buttons["th15.layout.save"].tap(); wait("width=768 height=1024")
        assertCenter(fire,portrait)
        editLayout(); dragControl(fire,100,-90); app.buttons["th15.layout.cancel"].tap()
        wait("width=768 height=1024"); assertCenter(fire,portrait)
        XCUIDevice.shared.orientation = .landscapeLeft; wait("width=1024 height=768")
        editLayout(); dragControl(fire,-190,-100); let landscape=fire.frame
        image("TH15-layout-landscape-editor"); app.buttons["th15.layout.save"].tap()
        wait("width=1024 height=768"); assertCenter(fire,landscape)
        XCUIDevice.shared.orientation = .portrait; wait("width=768 height=1024"); assertCenter(fire,portrait)
        app.terminate(); app.launch(); XCTAssertTrue(state.waitForExistence(timeout: 90))
        wait("autoBomb=1 "); assertCenter(fire,portrait); assertCenter(app.otherElements["th15.joystick"],portraitStick)
        openSettings(); setSwitch("hidden",true); closeSettings(); wait("hidden=1")
        XCTAssertFalse(fire.isHittable); XCTAssertFalse(slow.isHittable)
        XCTAssertFalse(app.buttons["th15.bomb"].isHittable); XCTAssertFalse(app.otherElements["th15.joystick"].isHittable)
        XCTAssertTrue(app.buttons["th15.pause"].isHittable); image("TH15-no-button")
        editLayout(); XCTAssertTrue(fire.isHittable); app.buttons["th15.layout.reset"].tap()
        app.buttons["th15.layout.save"].tap(); wait("hidden=1")
        openSettings(); setSwitch("autoBomb",false); setSwitch("toggleFire",false); setSwitch("toggleSlow",false); setSwitch("hidden",false)
        closeSettings(); wait("autoBomb=0 "); wait("hidden=0")
        assertCenter(fire,original)
        app.terminate(); app.launchArguments=["--ui-test"]; app.launch()
        wait("scene=0 screen=1 sub=2"); XCTAssertTrue(fire.isHittable)
        fire.tap(); wait("scene=0 screen=5 sub=2"); fire.tap(); wait("scene=0 screen=6 sub=2")
        app.terminate()
    }

}
