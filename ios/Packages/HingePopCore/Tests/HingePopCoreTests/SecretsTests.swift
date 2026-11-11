import XCTest
@testable import HingePopCore

final class SecretsTests: XCTestCase {
  func testEveryWorldHidesANamedSecretAndIdsAreUnique() {
    XCTAssertEqual(Set(Secrets.named.map(\.id)).count, Secrets.named.count)
    for a in Arena.allCases {
      XCTAssertNotNil(Secrets.named(Secrets.spotSecret(a).id), a.rawValue)
      let s = Secrets.spot(a, width: 390, height: 844)
      XCTAssertTrue((0...390).contains(s.x) && (0...844).contains(s.y) && s.r > 20, a.rawValue)
    }
  }

  func testEveryLevelFromTwoHidesASecretBubbleThatPaysOffWhenHit() {
    XCTAssertNil(Game(mode: .campaign(1), width: 390, height: 760, top: 70).secretBubble, "level 1 stays plain")
    for n in [2, 9, 33, 66, 80, 81, 250] {
      let g = Game(mode: .campaign(n), width: 390, height: 760, top: 70)
      g.ready = 0
      let id = try! XCTUnwrap(g.secretBubble, "level \(n)")
      let b = g.bubbles.first { $0.id == id }!
      XCTAssertNotEqual(b.kind, .boss)
      g.tap(b)
      XCTAssertTrue(g.events.contains { if case .secretBubble(n, _, _) = $0 { true } else { false } }, "level \(n)")
      XCTAssertNil(g.secretBubble)
    }
    XCTAssertEqual(Game(mode: .campaign(7), width: 390, height: 760, top: 70).secretBubble, Game(mode: .campaign(7), width: 390, height: 760, top: 70).secretBubble, "same level, same hiding place")
  }

  func testNodsNeverRunOutAndStayOriginal() {
    XCTAssertGreaterThanOrEqual(Set(Secrets.nods).count, 40)
    XCTAssertEqual(Secrets.nod(level: 1234), Secrets.nod(level: 1234))
    // Nods are winks, not borrowed lines or names.
    let banned = ["jedi", "force be", "88 miles", "great scott", "hogwarts", "winter is coming", "007", "shaken", "life finds a way", "clever girl", "marvel", "disney", "pokemon", "konami", "nintendo"]
    for line in Secrets.nods + Secrets.named.flatMap({ [$0.title, $0.line, $0.hint] }) {
      for word in banned { XCTAssertFalse(line.lowercased().contains(word), line) }
    }
  }

  func testTheCalendarAndTheCode() {
    XCTAssertEqual(Secrets.calendar(month: 10, day: 31, hour: 3).map(\.id), ["witching", "spooky"])
    XCTAssertTrue(Secrets.calendar(month: 6, day: 2, hour: 12).isEmpty)
    XCTAssertTrue(Secrets.spells([.left] + Secrets.code))
    XCTAssertFalse(Secrets.spells(Array(Secrets.code.dropLast())))
  }

  func testFindingIsRememberedOnceAndOldSavesLoad() throws {
    var p = GameProgress()
    XCTAssertTrue(p.find("answer")); XCTAssertFalse(p.find("answer"))
    p.find("nod-12"); p.find("nod-13")
    XCTAssertEqual(p.nodsFound, 2); XCTAssertEqual(p.namedFound, 1)
    let old = #"{"unlocked":3,"stars":{},"bestScores":{},"arcadeBest":0,"dailyBest":{},"seenTour":true,"seenVersusTour":false,"taught":[],"flick":true,"hingeGrace":true,"haptics":true}"#
    XCTAssertEqual(try JSONDecoder().decode(GameProgress.self, from: Data(old.utf8)).namedFound, 0)
  }
}
