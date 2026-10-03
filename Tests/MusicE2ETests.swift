import XCTest

final class MusicE2ETests: XCTestCase {
    var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-library"]
        app.launch()
    }
    func button(_ id: String) -> XCUIElement {
        #if os(iOS)
        if id.hasPrefix("nav-") {
            let title = String(id.dropFirst(4)).capitalized
            let tab = app.tabBars.buttons[title].firstMatch
            return tab.exists ? tab : app.descendants(matching:.any).matching(identifier:title).firstMatch
        }
        #endif
        #if os(macOS)
        if app.sheets.buttons[id].firstMatch.exists { return app.sheets.buttons[id].firstMatch }
        #endif
        return app.buttons[id].firstMatch
    }
    func menu(_ id:String) -> XCUIElement {
        #if os(macOS)
        return app.menuButtons[id].firstMatch
        #else
        return app.buttons[id].firstMatch
        #endif
    }
    func choose(_ title:String) {
        #if os(macOS)
        app.menuItems[title].firstMatch.hit()
        #else
        app.buttons[title].firstMatch.hit()
        #endif
    }
    func capture(_ name: String) {
        #if os(macOS)
        let attachment = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        #else
        let attachment = XCTAttachment(screenshot: app.screenshot())
        #endif
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    func reveal(_ element: XCUIElement) {
        for _ in 0..<8 {
            #if os(macOS)
            let frame = app.windows.firstMatch.frame
            if element.isHittable && element.frame.maxY < frame.maxY - 100 && element.frame.minY > frame.minY + 65 { return }
            let scroll = app.sheets.scrollViews.firstMatch.exists ? app.sheets.scrollViews.firstMatch : app.scrollViews.element(boundBy:1)
            scroll.scroll(byDeltaX:0,deltaY:-240)
            #else
            if element.isHittable { return }
            app.swipeUp()
            #endif
        }
    }
    func openWork() {
        button("nav-search").hit()
        let search = app.textFields["search-field"].firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.hit()
        search.typeText("Bach\n")
        let result = button("work-result-0")
        XCTAssertTrue(result.waitForExistence(timeout: 10))
        result.hit()
        XCTAssertTrue(button("play-recording-0").waitForExistence(timeout: 10))
    }
    func testSearchPlaybackLibraryAndOffline() throws {
        openWork()
        capture("work-recordings")
        button("play-recording-0").hit()
        XCTAssertTrue(button("player-pause").waitForExistence(timeout: 10))
        button("open-player").hit()
        XCTAssertTrue(app.sliders["playback-seek"].waitForExistence(timeout: 5))
        let clock = app.staticTexts["elapsed-time"].firstMatch
        XCTAssertTrue(clock.waitForExistence(timeout: 5))
        let advancing = XCTNSPredicateExpectation(predicate: NSPredicate(format:"label != '0:00'"), object:clock)
        XCTAssertEqual(XCTWaiter.wait(for:[advancing],timeout:8), .completed)
        capture("now-playing")
        button("player-pause").firstMatch.hit()
        app.sliders["playback-seek"].firstMatch.adjust(toNormalizedSliderPosition:0.5)
        XCTAssertGreaterThan(app.sliders["playback-seek"].firstMatch.normalizedSliderPosition,0.3)
        button("favorite-current").hit()
        button("download-current").hit()
        XCTAssertTrue(app.staticTexts["Downloaded"].firstMatch.waitForExistence(timeout: 15))
        button("close-player").hit()
        app.terminate()
        app.launchArguments = ["--uitesting", "--offline"]
        app.launch()
        XCTAssertTrue(button("player-play").waitForExistence(timeout: 10))
        button("player-play").hit()
        XCTAssertTrue(button("player-pause").waitForExistence(timeout: 10))
        button("nav-library").hit()
        capture("offline-library")
        button("open-player").hit()
        menu("track-options").hit()
        choose("Remove Download")
        XCTAssertTrue(button("download-current").waitForExistence(timeout:5))
        button("close-player").hit()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format:"label CONTAINS 'Complete Performance'")).firstMatch.exists)
    }
    func testQueueAndPlaylist() {
        openWork()
        let movementRecording = button("play-recording-3")
        reveal(movementRecording)
        movementRecording.hit()
        XCTAssertTrue(button("player-pause").waitForExistence(timeout: 10))
        button("player-pause").hit()
        button("open-queue").hit()
        XCTAssertTrue(button("repeat-mode").waitForExistence(timeout: 5))
        button("repeat-mode").hit()
        button("shuffle-mode").hit()
        capture("queue")
        button("close-queue").hit()
        button("nav-library").hit()
        button("new-playlist").hit()
        let field = app.textFields["playlist-name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.hit(); field.typeText("Evening")
        button("save-playlist").hit()
        XCTAssertTrue(button("playlist-Evening").waitForExistence(timeout: 5))
        capture("playlists")
        button("open-player").hit()
        menu("track-options").hit()
        choose("Add to Playlist")
        choose("Evening")
        button("close-player").hit()
        button("playlist-Evening").hit()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format:"label CONTAINS 'Prélude'")).firstMatch.waitForExistence(timeout:5))
        menu("playlist-options").hit()
        choose("Rename")
        let rename = app.textFields["playlist-name"].firstMatch
        XCTAssertTrue(rename.waitForExistence(timeout:5))
        rename.hit()
        #if os(macOS)
        rename.typeKey("a",modifierFlags:.command)
        rename.typeText("Night Music")
        #else
        rename.typeText(String(repeating:XCUIKeyboardKey.delete.rawValue,count:7) + "Night Music")
        #endif
        button("save-playlist").hit()
        XCTAssertTrue(app.staticTexts["Night Music"].firstMatch.waitForExistence(timeout:5))
        capture("playlist-renamed")
        button("remove-playlist-track").hit()
        XCTAssertTrue(app.staticTexts["Add Your First Track"].firstMatch.waitForExistence(timeout:5))
        menu("playlist-options").hit()
        choose("Delete Playlist")
        button("Delete Playlist").hit()
        XCTAssertFalse(button("playlist-Night Music").exists)
    }
    #if os(iOS)
    func testReadableLayout() {
        capture("home-layout")
        let explore = button("Explore Bach’s Cello Suites")
        reveal(explore)
        explore.hit()
        XCTAssertTrue(button("play-recording-0").waitForExistence(timeout:10))
        reveal(button("play-recording-0"))
        capture("readable-work")
        button("play-recording-0").hit()
        XCTAssertTrue(button("player-pause").waitForExistence(timeout:10))
        button("open-player").hit()
        reveal(button("player-pause"))
        capture("readable-player")
        button("player-pause").hit()
        XCTAssertTrue(button("player-play").waitForExistence(timeout:5))
    }
    #endif
    #if os(macOS)
    func testQueueDragOrder() {
        openWork()
        let recording = button("play-recording-3")
        reveal(recording); recording.hit()
        XCTAssertTrue(button("player-pause").waitForExistence(timeout:10))
        button("player-pause").hit()
        button("open-queue").hit()
        XCTAssertTrue(button("repeat-mode").waitForExistence(timeout:5))
        let queue = app.sheets.firstMatch
        let second = queue.buttons.matching(NSPredicate(format:"label BEGINSWITH '2. Allemande'")).firstMatch
        let third = queue.buttons.matching(NSPredicate(format:"label BEGINSWITH '3. Courante'")).firstMatch
        XCTAssertTrue(second.waitForExistence(timeout:5))
        queue.images["reorder-2. Allemande"].firstMatch.click(forDuration:0.5,thenDragTo:third)
        XCTAssertGreaterThan(second.frame.minY,third.frame.minY)
        capture("queue-reordered")
        button("Clear").hit()
        if button("Clear").isEnabled { button("Clear").hit() }
        XCTAssertFalse(button("Clear").isEnabled)
        XCTAssertFalse(second.exists)
    }
    func testMiniPlayerSharesPlaybackAndSearchShortcut() {
        capture("home")
        openWork()
        button("play-recording-0").hit()
        XCTAssertTrue(button("player-pause").waitForExistence(timeout:10))
        button("Open Mini Player").hit()
        let mini = app.windows["Mini Player"]
        XCTAssertTrue(mini.waitForExistence(timeout:5))
        mini.buttons["player-pause"].firstMatch.hit()
        XCTAssertTrue(mini.buttons["player-play"].firstMatch.waitForExistence(timeout:5))
        let attachment = XCTAttachment(screenshot:mini.screenshot())
        attachment.name = "mini-player"; attachment.lifetime = .keepAlways; add(attachment)
        mini.typeKey("w",modifierFlags:.command)
        app.typeKey("f",modifierFlags:.command)
        XCTAssertTrue(app.textFields["search-field"].firstMatch.waitForExistence(timeout:5))
    }
    #endif
    func testDownloadCancellationAndInvalidFile() {
        app.terminate()
        app.launchArguments = ["--uitesting", "--reset-library", "--slow-download"]
        app.launch()
        openWork()
        button("play-recording-0").hit()
        XCTAssertTrue(button("player-pause").waitForExistence(timeout:10))
        button("open-player").hit()
        reveal(button("download-current"))
        button("download-current").hit()
        XCTAssertTrue(button("Cancel").waitForExistence(timeout:3))
        button("Cancel").hit()
        XCTAssertTrue(button("download-current").waitForExistence(timeout:5))
        XCTAssertFalse(app.staticTexts["Downloaded"].exists)
        capture("download-cancelled")
        app.terminate()
        app.launchArguments = ["--uitesting", "--reset-library", "--corrupt-download"]
        app.launch()
        openWork()
        button("play-recording-0").hit()
        XCTAssertTrue(button("player-pause").waitForExistence(timeout:10))
        button("open-player").hit()
        reveal(button("download-current"))
        button("download-current").hit()
        XCTAssertTrue(app.buttons["download-current"].firstMatch.waitForExistence(timeout:10))
        let retry = XCTNSPredicateExpectation(predicate:NSPredicate(format:"label CONTAINS 'Retry'"), object:button("download-current"))
        XCTAssertEqual(XCTWaiter.wait(for:[retry],timeout:10),.completed)
        XCTAssertFalse(app.staticTexts["Downloaded"].exists)
        capture("invalid-download")
    }
    func testSourceOnlyRecording() {
        app.terminate()
        app.launchArguments = ["--uitesting","--reset-library","--source-access"]
        app.launch()
        button("nav-search").hit()
        let field = app.textFields["search-field"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout:10))
        field.hit(); field.typeText("Mozart\n")
        XCTAssertTrue(button("work-result-0").waitForExistence(timeout:10))
        button("work-result-0").hit()
        let source = app.descendants(matching:.any).matching(identifier:"source-recording-0").firstMatch
        XCTAssertTrue(source.waitForExistence(timeout:10))
        XCTAssertFalse(button("play-recording-0").exists)
        let notice = app.staticTexts["source-access-0"].firstMatch
        XCTAssertTrue(notice.exists)
        XCTAssertTrue((notice.value as? String ?? notice.label).contains("IMSLP source: EU"))
        capture("mozart-source-access")
    }
    func testEmptyAndErrorStates() {
        button("nav-search").hit()
        let field = app.textFields["search-field"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.hit(); field.typeText("zzzz")
        XCTAssertTrue(app.staticTexts["No Results"].waitForExistence(timeout: 8))
        capture("empty-search")
        app.terminate()
        app.launchArguments = ["--uitesting", "--offline", "--reset-library"]
        app.launch()
        button("nav-search").hit()
        let offline = app.textFields["search-field"].firstMatch
        offline.hit(); offline.typeText("Bach")
        XCTAssertTrue(app.staticTexts["No Internet Connection"].waitForExistence(timeout: 8))
        capture("offline-error")
    }
}

extension XCUIElement {
    func hit() {
        #if os(macOS)
        click()
        #else
        tap()
        #endif
    }
}
