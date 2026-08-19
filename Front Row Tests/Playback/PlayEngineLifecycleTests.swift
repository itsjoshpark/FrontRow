//
//  PlayEngineLifecycleTests.swift
//  Front Row Tests
//
//  Created by Joshua Park on 8/17/26.
//

import AVFoundation
import Testing

@testable import Front_Row

/// What `PlayEngine` leaves behind between one file and the next.
///
/// Every other test in this bundle is a function in and a value out. These drive the real engine
/// against real assets, because the thing being measured is what it holds on to - and nothing
/// holds on to anything in a pure function.
///
/// Serialized, and against `PlayEngine.shared`: there is one engine in the app and one `AVPlayer`
/// inside it, so tests that open files cannot run alongside each other. The fixtures are never
/// added to recent documents, so nothing here reaches `UserDefaults` or the user's own list.
@MainActor
@Suite(.serialized)
struct PlayEngineLifecycleTests {

    private var engine: PlayEngine { PlayEngine.shared }

    /// Returns the engine to rest, whatever the test left open.
    private func reset() {
        engine.closeFile()
    }

    // MARK: - Holding on to items

    /// Opening a second file has to let the first player item go. The item is where the decoded
    /// media sits, so one held by a stale subscription is the most expensive thing this app can
    /// leak.
    @Test(.timeLimit(.minutes(2)))
    func openingASecondFileReleasesTheFirstItem() async throws {
        let directory = try PlaybackFixtures.makeDirectory()
        defer {
            reset()
            PlaybackFixtures.remove(directory)
        }

        let first = try await PlaybackFixtures.makeMovie(named: "first", in: directory)
        let second = try await PlaybackFixtures.makeMovie(named: "second", in: directory)

        #expect(await engine.loadAndPlay(url: first) == .opened)
        weak let firstItem = engine.player.currentItem
        #expect(firstItem != nil)

        #expect(await engine.loadAndPlay(url: second) == .opened)
        await settle(until: { firstItem == nil })

        #expect(firstItem == nil, "The first player item outlived the file that replaced it")
    }

    @Test(.timeLimit(.minutes(2)))
    func closingReleasesTheItem() async throws {
        let directory = try PlaybackFixtures.makeDirectory()
        defer { PlaybackFixtures.remove(directory) }

        let movie = try await PlaybackFixtures.makeMovie(named: "movie", in: directory)

        #expect(await engine.loadAndPlay(url: movie) == .opened)
        weak let item = engine.player.currentItem
        #expect(item != nil)

        engine.closeFile()
        await settle(until: { item == nil })

        #expect(item == nil, "Closing left the player item behind")
    }

    /// The shape of use that shows accumulation: several files in a row, each one's item expected
    /// to go when the next arrives. A subscription set that grows by three per open would keep
    /// every one of these alive.
    @Test(.timeLimit(.minutes(3)))
    func repeatedOpensLeaveOnlyTheCurrentItemAlive() async throws {
        let directory = try PlaybackFixtures.makeDirectory()
        defer {
            reset()
            PlaybackFixtures.remove(directory)
        }

        var movies: [URL] = []
        for index in 0..<4 {
            movies.append(try await PlaybackFixtures.makeMovie(named: "m\(index)", in: directory))
        }

        let previous = WeakItems()

        for movie in movies {
            #expect(await engine.loadAndPlay(url: movie) == .opened)
            await settle()
            previous.append(engine.player.currentItem)
        }

        // Every item but the one playing now.
        await settle(until: { previous.aliveCount == 1 })
        #expect(
            previous.aliveCount == 1,
            "\(previous.aliveCount) player items are still alive after four opens"
        )
    }

    // MARK: - A file that will not open

    /// Bytes that are not a movie report as unplayable rather than throwing or hanging.
    @Test(.timeLimit(.minutes(1)))
    func unreadableBytesReportAFailureRatherThanOpening() async throws {
        let directory = try PlaybackFixtures.makeDirectory()
        defer {
            reset()
            PlaybackFixtures.remove(directory)
        }

        let rubbish = try PlaybackFixtures.makeUnplayable(named: "rubbish", in: directory)

        let result = await engine.loadAndPlay(url: rubbish)
        #expect(result != .opened)
    }

    @Test(.timeLimit(.minutes(1)))
    func aFileThatIsNotThereReportsAFailure() async throws {
        let directory = try PlaybackFixtures.makeDirectory()
        defer {
            reset()
            PlaybackFixtures.remove(directory)
        }

        let missing = directory.appending(path: "never-written.mp4")

        let result = await engine.loadAndPlay(url: missing)
        #expect(result != .opened)
    }

    /// A failed open returns before `fileURL` is reassigned and before the player is handed a new
    /// item, so the engine goes on answering for - and playing - the file that was already open.
    ///
    /// That is the intended reading of the early returns: a file that will not open should not
    /// take down the one that did. This test is here to say so out loud, because the same early
    /// returns skip the rest of the bookkeeping too.
    @Test(.timeLimit(.minutes(2)))
    func aFailedOpenLeavesTheFileThatWasAlreadyPlaying() async throws {
        let directory = try PlaybackFixtures.makeDirectory()
        defer {
            reset()
            PlaybackFixtures.remove(directory)
        }

        let movie = try await PlaybackFixtures.makeMovie(named: "movie", in: directory)
        let rubbish = try PlaybackFixtures.makeUnplayable(named: "rubbish", in: directory)

        #expect(await engine.loadAndPlay(url: movie) == .opened)
        await settle()
        let playingItem = engine.player.currentItem

        #expect(await engine.loadAndPlay(url: rubbish) != .opened)
        await settle()

        #expect(engine.fileURL == movie)
        #expect(engine.isLoaded)
        #expect(engine.player.currentItem === playingItem)
        #expect(engine.videoSize != .zero, "The window would have nothing left to shape itself to")
    }

    /// Closing after a failed open still leaves the engine empty. The failure path sets state the
    /// success path would have completed, so this is the one route into `closeFile` where what it
    /// is clearing and what was playing disagree.
    @Test(.timeLimit(.minutes(2)))
    func closingAfterAFailedOpenLeavesNothingBehind() async throws {
        let directory = try PlaybackFixtures.makeDirectory()
        defer { PlaybackFixtures.remove(directory) }

        let movie = try await PlaybackFixtures.makeMovie(named: "movie", in: directory)
        let rubbish = try PlaybackFixtures.makeUnplayable(named: "rubbish", in: directory)

        #expect(await engine.loadAndPlay(url: movie) == .opened)
        weak let item = engine.player.currentItem

        #expect(await engine.loadAndPlay(url: rubbish) != .opened)
        engine.closeFile()
        await settle(until: { item == nil })

        #expect(engine.fileURL == nil)
        #expect(!engine.isLoaded)
        #expect(engine.videoSize == .zero)
        #expect(engine.player.currentItem == nil)
        #expect(item == nil, "The item that was playing outlived a close")
    }

    // MARK: - A close arriving mid-open

    /// A close landing inside an open makes the open fail, and fail as though the file itself were
    /// at fault.
    ///
    /// `openFile` suspends three times loading the asset. `closeFile` runs `asset?.cancelLoading()`
    /// on the way past, which is the asset the open is waiting on, so `load(.isPlayable)` throws
    /// and the open returns `.unreadable` - the same answer a deleted file gives.
    ///
    /// It matters because of what the caller does with that answer.
    /// `openRecentDocumentAndPresent` treats anything but `.opened` as the file's fault and raises
    /// the unopenable-recent alert, whose dismissal drops the entry. A perfectly good file can
    /// therefore be reported as unreadable and lose its place in recents, on timing alone.
    ///
    /// The player window is torn down and rebuilt around every open after the first, so a
    /// `closeFile` in that neighbourhood is routine; what is not routine is it landing inside the
    /// load rather than either side of it.
    @Test(.timeLimit(.minutes(2)))
    func aCloseArrivingMidOpenMakesAGoodFileLookUnreadable() async throws {
        let directory = try PlaybackFixtures.makeDirectory()
        defer {
            reset()
            PlaybackFixtures.remove(directory)
        }

        let movie = try await PlaybackFixtures.makeMovie(named: "movie", in: directory)

        let open = Task { await engine.loadAndPlay(url: movie) }
        await yieldToTheOpen()
        engine.closeFile()

        #expect(await open.value == .unreadable)
        await settle()

        // The open never got as far as writing anything, so the close's emptying stands.
        #expect(engine.fileURL == nil)
        #expect(!engine.isLoaded)
        #expect(engine.player.currentItem == nil)

        // The same file opens on the next attempt, which is what marks the failure as timing
        // rather than the file.
        #expect(await engine.loadAndPlay(url: movie) == .opened)
    }

    /// An interrupted open leaves nothing half-installed for the close after it to trip over, and
    /// the second close is a no-op rather than a second teardown of the same state.
    @Test(.timeLimit(.minutes(2)))
    func closingAgainAfterAMidOpenCloseIsHarmless() async throws {
        let directory = try PlaybackFixtures.makeDirectory()
        defer { PlaybackFixtures.remove(directory) }

        let movie = try await PlaybackFixtures.makeMovie(named: "movie", in: directory)

        let open = Task { await engine.loadAndPlay(url: movie) }
        await yieldToTheOpen()
        engine.closeFile()
        _ = await open.value

        engine.closeFile()
        await settle()

        #expect(engine.fileURL == nil)
        #expect(!engine.isLoaded)
        #expect(engine.videoSize == .zero)
        #expect(engine.player.currentItem == nil)
    }

    /// Ten interrupted opens, each followed by the retry that succeeds - the shape of a window
    /// rebuild that keeps catching the load, and of the user opening the file again afterwards.
    /// Only the item playing at the end may still be alive.
    @Test(.timeLimit(.minutes(3)))
    func repeatedMidOpenClosesDoNotAccumulate() async throws {
        let directory = try PlaybackFixtures.makeDirectory()
        defer {
            reset()
            PlaybackFixtures.remove(directory)
        }

        let movie = try await PlaybackFixtures.makeMovie(named: "movie", in: directory)
        let items = WeakItems()

        for _ in 0..<10 {
            let open = Task { await engine.loadAndPlay(url: movie) }
            await yieldToTheOpen()
            engine.closeFile()
            _ = await open.value

            #expect(await engine.loadAndPlay(url: movie) == .opened)
            items.append(engine.player.currentItem)
        }

        engine.closeFile()
        await settle(until: { items.aliveCount == 0 })

        #expect(items.aliveCount == 0, "\(items.aliveCount) items survived ten interrupted opens")
    }

    // MARK: - Repeated cycles

    /// Ten opens and closes, checking the engine comes back to the same resting state each time
    /// rather than drifting. Cheap to run and the first thing to break if a close stops undoing
    /// what an open did.
    @Test(.timeLimit(.minutes(3)))
    func openAndCloseCyclesReturnToRest() async throws {
        let directory = try PlaybackFixtures.makeDirectory()
        defer { PlaybackFixtures.remove(directory) }

        let movie = try await PlaybackFixtures.makeMovie(named: "movie", in: directory)
        let items = WeakItems()

        for cycle in 1...10 {
            #expect(
                await engine.loadAndPlay(url: movie) == .opened, "Cycle \(cycle) failed to open")
            items.append(engine.player.currentItem)

            engine.closeFile()

            #expect(engine.fileURL == nil, "Cycle \(cycle) left a file behind")
            #expect(!engine.isLoaded, "Cycle \(cycle) stayed loaded")
            #expect(engine.player.currentItem == nil, "Cycle \(cycle) left an item behind")
        }

        await settle(until: { items.aliveCount == 0 })
        #expect(items.aliveCount == 0, "\(items.aliveCount) player items survived ten cycles")
    }

    /// Lets a just-started open reach its first suspension point, so what follows lands inside it
    /// rather than before it began.
    ///
    /// Once, and once only. The open is already queued when this yields, so it runs first and stops
    /// at the load; what resumes next is this, ahead of anything that load queues behind it. A
    /// second hand-over would give the load a turn to finish, leaving the close nothing to catch.
    private func yieldToTheOpen() async {
        await Task.yield()
    }

    /// Gives the main run loop a turn, so the observers that fire on it have run and the
    /// autoreleased references picked up along the way have gone.
    private func settle() async {
        for _ in 0..<3 {
            try? await Task.sleep(for: .milliseconds(120))
        }
    }

    /// Waits until `condition` holds, giving up after `timeout`.
    ///
    /// An item goes when the last thing holding it lets go, which happens inside AVFoundation and
    /// has no event to wait on. Something genuinely held still fails, once the deadline passes.
    private func settle(until condition: () -> Bool, timeout: Duration = .seconds(10)) async {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(50))
        }
    }
}

/// Weak references to player items, to be counted once they have all had their chance to go.
@MainActor
private final class WeakItems {
    private var boxes: [Box] = []

    private final class Box {
        weak var item: AVPlayerItem?
        init(_ item: AVPlayerItem?) { self.item = item }
    }

    func append(_ item: AVPlayerItem?) {
        boxes.append(Box(item))
    }

    var aliveCount: Int {
        boxes.count { $0.item != nil }
    }
}
