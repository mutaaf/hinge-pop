// The save never loses progress: corrupt, truncated, empty and future saves all load the best progress there is, and
// the bytes this build couldn't use are kept for a build that can.
import XCTest
@testable import HingePopCore

final class SaveVaultTests: XCTestCase {
  func played(_ upTo: Int = 23) -> GameProgress {
    var p = GameProgress()
    for l in 1..<upTo { p.record(level: l, stars: 1 + l % 3, score: l * 100, grade: .b, earned: [true, l % 2 == 0, false]) }
    p.recordArcade(score: 4200, wave: 12)
    p.dailyBest["2026-11-18"] = 900
    p.taught = ["snapped", "world-1"]
    p.difficulty = .overdrive
    p.arena = .reef
    return p
  }
  func vault(_ m: MemorySaveMedium = MemorySaveMedium()) -> SaveVault { SaveVault(medium: m) }
  func bytes(_ p: GameProgress) -> Data { try! JSONEncoder().encode(p) }

  func testAFreshInstallStartsEmptyAndWritesNothing() {
    let m = MemorySaveMedium()
    let l = vault(m).load()
    XCTAssertEqual(l.source, .none)
    XCTAssertEqual(l.progress, GameProgress())
    XCTAssertTrue(m.slots.isEmpty)
  }

  func testRoundTripStampsTheSchemaAndBacksUpAtLaunch() throws {
    let m = MemorySaveMedium()
    let v = vault(m)
    XCTAssertTrue(v.save(played()))
    let l = vault(m).load()
    XCTAssertEqual(l.source, .primary)
    XCTAssertEqual(l.progress.unlocked, 23)
    XCTAssertEqual(l.progress.saveSchema, SaveVault.schema)
    XCTAssertEqual(l.progress.arena, .reef)
    XCTAssertEqual(m.slots[v.backup], m.slots[v.primary], "a clean load is the session's backup")
    XCTAssertNil(m.slots[v.kept])
    // Older saves (plain GameProgress JSON from before the vault) load as they are.
    let old = MemorySaveMedium()
    old.slots["hinge-pop-progress"] = bytes(played(9))
    XCTAssertEqual(vault(old).load().progress.unlocked, 9)
  }

  func testACorruptSaveFallsBackToTheBackupAndKeepsTheBytes() {
    let m = MemorySaveMedium()
    let v = vault(m)
    v.save(played(40)); v.backupNow()
    v.save(played(41))
    m.slots[v.primary] = Data("{\"unlocked\": 41, \"stars\": [1, 2, \u{0} garbage".utf8)
    let l = vault(m).load()
    XCTAssertEqual(l.source, .backup)
    XCTAssertEqual(l.progress.unlocked, 40)
    XCTAssertNotNil(m.slots[v.kept], "the unreadable bytes are kept")
    XCTAssertEqual(SaveVault.decode(m.slots[v.primary])?.unlocked, 40, "the backup is the save again")
  }

  func testATruncatedSave() {
    let m = MemorySaveMedium()
    let v = vault(m)
    v.save(played(30)); v.backupNow()
    let full = m.slots[v.primary]!
    for cut in [1, full.count / 3, full.count / 2, full.count - 1] {
      let n = MemorySaveMedium()
      n.slots = m.slots
      n.slots[v.primary] = full.prefix(cut)
      let l = vault(n).load()
      XCTAssertEqual(l.source, .backup, "cut at \(cut)")
      XCTAssertEqual(l.progress.unlocked, 30)
    }
    // No backup either: a fresh start, but the bytes stay kept and the next save doesn't touch them.
    let n = MemorySaveMedium()
    n.slots[v.primary] = full.prefix(full.count / 2)
    let l = vault(n).load()
    XCTAssertEqual(l.source, .fresh)
    XCTAssertEqual(n.slots[v.kept], full.prefix(full.count / 2))
    vault(n).save(l.progress)
    XCTAssertEqual(n.slots[v.kept], full.prefix(full.count / 2))
  }

  func testAnEmptySave() {
    let m = MemorySaveMedium()
    let v = vault(m)
    v.save(played(12)); v.backupNow()
    m.slots[v.primary] = Data()
    let l = vault(m).load()
    XCTAssertEqual(l.source, .backup)
    XCTAssertEqual(l.progress.unlocked, 12)
    XCTAssertNil(m.slots[v.kept], "nothing to keep")
  }

  func testAFieldThisBuildCantReadIsDroppedNotTheSave() throws {
    // A newer build's backdrop and difficulty this build doesn't know: everything else survives.
    var obj = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes(played(55))) as? [String: Any])
    obj["arena"] = "nebula"
    obj["difficultyChoice"] = "nightmare"
    let m = MemorySaveMedium()
    let v = vault(m)
    m.slots[v.primary] = try JSONSerialization.data(withJSONObject: obj)
    let l = vault(m).load()
    XCTAssertEqual(l.source, .salvaged)
    XCTAssertEqual(l.progress.unlocked, 55)
    XCTAssertEqual(l.progress.arcadeBest, 4200)
    XCTAssertNil(l.progress.arena)
    XCTAssertEqual(l.progress.difficulty, .normal)
    XCTAssertNotNil(m.slots[v.kept], "the original, for a build that can read it")
  }

  func testAFutureSaveLoadsAndItsOriginalIsKept() throws {
    var obj = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes(played(70))) as? [String: Any])
    obj["saveSchema"] = SaveVault.schema + 1
    obj["somethingNew"] = ["a": 1]
    let original = try JSONSerialization.data(withJSONObject: obj)
    let m = MemorySaveMedium()
    let v = vault(m)
    m.slots[v.primary] = original
    let l = vault(m).load()
    XCTAssertEqual(l.source, .primary)
    XCTAssertTrue(l.fromTheFuture)
    XCTAssertEqual(l.progress.unlocked, 70)
    XCTAssertEqual(m.slots[v.kept], original)
    XCTAssertNil(m.slots[v.backup], "a newer build's save isn't this build's backup")
    // Playing on writes this build's save; the newer original stays kept.
    var p = l.progress
    p.record(level: 70, stars: 3, score: 1)
    vault(m).save(p)
    XCTAssertEqual(m.slots[v.kept], original)
    let again = vault(m).load()
    XCTAssertEqual(again.progress.unlocked, 71, "the progress made here wins: it's further along")
    XCTAssertEqual(m.slots[v.kept], original, "still kept while it's from a newer build")
  }

  func testAKeptSaveIsRescuedOnceItReadsAndIsFurtherAlong() {
    let m = MemorySaveMedium()
    let v = vault(m)
    // A launch that couldn't read the save started over and played a little.
    m.slots[v.kept] = bytes(played(60))
    v.save(played(3))
    let l = vault(m).load()
    XCTAssertEqual(l.source, .rescued)
    XCTAssertEqual(l.progress.unlocked, 60)
    XCTAssertEqual(SaveVault.decode(m.slots[v.primary])?.unlocked, 60)
    XCTAssertNil(m.slots[v.kept])
    // A kept copy that's behind goes once the save loads cleanly.
    m.slots[v.kept] = bytes(played(5))
    XCTAssertEqual(vault(m).load().source, .primary)
    XCTAssertNil(m.slots[v.kept])
  }

  func testAFailedWriteChangesNothing() {
    let m = MemorySaveMedium()
    let v = vault(m)
    v.save(played(20))
    let before = m.slots
    m.failWrites = true
    XCTAssertFalse(v.save(played(21)))
    XCTAssertEqual(m.slots, before)
  }

  func testFilesAreWrittenAtomicallyAndReadBack() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("hp-vault-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: dir) }
    let f = FileSaveMedium(folder: dir)
    let v = SaveVault(medium: f)
    XCTAssertTrue(v.save(played(33)))
    XCTAssertEqual(SaveVault(medium: FileSaveMedium(folder: dir)).load().progress.unlocked, 33)
    try Data("nope".utf8).write(to: dir.appendingPathComponent("hinge-pop-progress.json"))
    let l = SaveVault(medium: FileSaveMedium(folder: dir)).load()
    XCTAssertEqual(l.source, .backup)
    XCTAssertEqual(l.progress.unlocked, 33)
    f.remove(v.kept)
    XCTAssertNil(f.read(v.kept))
  }

  func testEveryProgressFieldSurvivesTheTrip() {
    let m = MemorySaveMedium()
    var p = played(80)
    p.find("nod-12"); p.caught(Cameo.allCases[0]); p.seenNotes = "0.5.0"; p.trail = "reef"; p.usage = false; p.sound = true
    p.markCheered(.world(1))
    vault(m).save(p)
    var back = vault(m).load().progress
    back.saveSchema = nil
    XCTAssertEqual(back, p)
  }
}
