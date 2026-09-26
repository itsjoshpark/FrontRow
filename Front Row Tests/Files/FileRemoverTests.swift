//
//  FileRemoverTests.swift
//  Front Row Tests
//

import Foundation
import Testing

@testable import Front_Row

/// Removing the playing file acts only on the file that was named, and cleans up after itself only
/// once the file is actually gone.
///
/// Deletes rather than trashes wherever a removal succeeds, so a test run leaves nothing in the
/// user's Trash.
@MainActor
struct FileRemoverTests {

    private let presentationModel = PresentationModel()
    private let recents: RecentDocumentsStore

    init() {
        let suite = "FileRemoverTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        recents = RecentDocumentsStore(
            defaults: defaults, bookmarkProvider: FakeBookmarkProvider(),
            mountedVolumes: FakeMountedVolumesProvider())
    }

    private func makeFile() throws -> URL {
        let file = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).mov")
        try Data().write(to: file)
        return file
    }

    private func remover(playing file: URL?) -> FileRemover {
        FileRemover(
            playingFile: { file }, recentDocuments: recents, presentationModel: presentationModel)
    }

    @Test
    func removesThePlayingFileAndItsRecentsEntry() throws {
        let file = try makeFile()
        recents.noteRecentDocument(file)

        #expect(remover(playing: file).remove(file, .delete))

        #expect(!FileManager.default.fileExists(atPath: file.path(percentEncoded: false)))
        #expect(!recents.recentURLs.contains(file), "The entry outlived its file")
        #expect(presentationModel.fileRemovalAlert == nil)
    }

    /// The confirmation names one file, and something else can be opened while it's up. Removing
    /// whatever is playing by then would delete a file nobody was asked about.
    @Test
    func refusesAFileThatIsNoLongerPlaying() throws {
        let named = try makeFile()
        let nowPlaying = try makeFile()
        defer {
            try? FileManager.default.removeItem(at: named)
            try? FileManager.default.removeItem(at: nowPlaying)
        }

        #expect(!remover(playing: nowPlaying).remove(named, .delete))

        #expect(FileManager.default.fileExists(atPath: named.path(percentEncoded: false)))
        #expect(FileManager.default.fileExists(atPath: nowPlaying.path(percentEncoded: false)))
        #expect(presentationModel.fileRemovalAlert == nil)
    }

    /// A stream, or nothing at all, has no file behind it to remove.
    @Test
    func refusesWhenNoLocalFileIsPlaying() throws {
        let file = try makeFile()
        defer { try? FileManager.default.removeItem(at: file) }

        #expect(!remover(playing: nil).remove(file, .delete))

        #expect(FileManager.default.fileExists(atPath: file.path(percentEncoded: false)))
    }

    /// A file that couldn't be removed is still there, so its recents entry stays too.
    @Test
    func aFailureRaisesAnAlertAndKeepsTheRecentsEntry() throws {
        let file = try makeFile()
        recents.noteRecentDocument(file)
        try FileManager.default.removeItem(at: file)

        #expect(!remover(playing: file).remove(file, .trash))

        guard case .failure(let failure) = presentationModel.fileRemovalAlert else {
            Issue.record("No failure was raised")
            return
        }
        #expect(failure.url == file)
        #expect(failure.removal == .trash)
        #expect(recents.recentURLs.contains(file), "A failed removal dropped the entry")
    }
}
