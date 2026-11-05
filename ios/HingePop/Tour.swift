import SwiftUI
import HingePopCore

enum TourKind { case solo, versus }

enum SpotTarget: Equatable {
  case hinge, arena, bubble, meter, shields, streak, score, hud
}

struct TourStep {
  var title: String
  var body: String
  var target: SpotTarget
  var todo: String? = nil
  var done: String? = nil
  var input = false
  var live = false
  var last: String? = nil
  var retryText: String? = nil
  var retry: ((Game) -> Bool)? = nil
  var waits: ((Game) -> Bool)? = nil
  var before: ((Game) -> Void)? = nil
  var scene: (Session, Game) -> Void = { _, _ in }
}

@MainActor
enum TourScript {
  static func steps(_ kind: TourKind) -> [TourStep] {
    let t = Tuning()
    if kind == .versus {
      return [
        TourStep(title: "Two players, one hinge",
                 body: "One side each, with your own shields and score.",
                 target: .hinge, scene: { _, g in g.put(.basic, size: 0, u: 0.5, v: 0.2, degrees: 35, speed: 0); g.put(.basic, size: 0, u: 0.5, v: 0.8, degrees: 35, speed: 0) }),
        TourStep(title: "Stay on your side",
                 body: "Touches only reach your own side.",
                 target: .arena, todo: "Tap a bubble.", done: "Same moves as solo.", input: true,
                 waits: { $0.players[0].taps + $0.players[1].taps >= 1 },
                 scene: { _, g in g.put(.basic, size: 0, u: 0.25, v: 0.2, degrees: 35, speed: 0); g.put(.basic, size: 0, u: 0.25, v: 0.8, degrees: 35, speed: 0) }),
        TourStep(title: "Crossings land on your rival",
                 body: "Watch this bubble leave the left side.",
                 target: .hinge, todo: "Watch the bubble.", done: "It cost the left player, and the pieces landed on the right.",
                 waits: { $0.players[0].crossings >= 1 },
                 scene: { _, g in g.put(.basic, size: 0, u: 0.45, v: 0.36, degrees: 60, speed: 0.8) }),
        TourStep(title: "Two ways to win",
                 body: "Last shield standing wins. If all clear, top score wins.",
                 target: .hud, last: "Start match"),
      ]
    }
    return [
      TourStep(title: "Welcome to Hinge Pop",
               body: "Clear every bubble. Keep the big ones off this line.",
               target: .hinge, scene: { _, g in g.put(.basic, size: 0, u: 0.3, v: 0.2, degrees: 35, speed: 0); g.put(.basic, size: 1, u: 0.72, v: 0.28, degrees: 145, speed: 0) }),
      TourStep(title: "Tap to split", body: "Touch a bubble to split it.",
               target: .bubble, todo: "Tap the big bubble.", done: "One became two.", input: true,
               waits: { $0.players[0].taps >= 1 },
               scene: { s, g in s.tourBubble = g.put(.basic, size: 0, u: 0.5, v: 0.22, degrees: 35, speed: 0) }),
      TourStep(title: "Four sizes", body: "Smaller is faster and pays more. Tiny ones pop for good.",
               target: .arena, scene: { _, g in for s in 0..<4 { g.put(.basic, size: s, u: 0.14 + Double(s) * 0.25, v: 0.22, degrees: 35, speed: 0) } }),
      TourStep(title: "Weight matters", body: "Big ones shove little ones. Watch.",
               target: .arena, live: true, scene: { _, g in g.put(.basic, size: 0, u: 0.12, v: 0.2, degrees: 0); g.put(.basic, size: 3, u: 0.62, v: 0.2, degrees: 0, speed: 0) }),
      TourStep(title: "Swipe to slice", body: "One swipe hits everything it crosses.",
               target: .arena, todo: "Swipe across both bubbles in one stroke.", done: "The pieces fly the way you swiped.", input: true,
               retryText: "That was a tap. This time, drag your finger across both bubbles.",
               retry: { $0.players[0].taps >= 1 && $0.players[0].flicks == 0 }, waits: { $0.players[0].flicks >= 2 },
               scene: { _, g in g.put(.basic, size: 1, u: 0.3, v: 0.24, degrees: 35, speed: 0); g.put(.basic, size: 1, u: 0.7, v: 0.24, degrees: 35, speed: 0) }),
      TourStep(title: "Chain pops", body: "Pop one tiny bubble and its neighbours go too.",
               target: .arena, todo: "Tap any tiny bubble in the bunch.", done: "One tap, the whole bunch.", input: true,
               waits: { $0.players[0].chained >= 1 },
               scene: { _, g in for (u, v) in [(0.4, 0.24), (0.47, 0.2), (0.54, 0.24), (0.47, 0.28), (0.6, 0.2)] { g.put(.basic, size: 3, u: u, v: v, degrees: 35, speed: 0) } }),
      TourStep(title: "The hinge bites", body: "Watch a big bubble reach the line.", target: .hinge, todo: "Watch the bubble.",
               done: "That cost a whole shield. Bigger bubbles hit harder.",
               waits: { $0.players[0].crossings >= 1 }, scene: { _, g in g.put(.basic, size: 0, u: 0.3, v: 0.34, degrees: 70, speed: 0.8) }),
      TourStep(title: "The overload meter", body: "Crossings fill this. When it fills, you lose a shield.",
               target: .meter, before: { $0.players[0].meter = 2 }),
      TourStep(title: "Shields", body: "Lose all \(t.shields) and the level restarts.",
               target: .shields, before: { $0.players[0].shields = 2 }),
      TourStep(title: "Tiny = free", body: "Good news: watch a tiny one reach the line.", target: .hinge, todo: "Watch the bubble.",
               done: "Free points, no cost.",
               waits: { $0.players[0].zaps >= 1 }, scene: { _, g in g.put(.basic, size: 3, u: 0.5, v: 0.36, degrees: 70, speed: 0.5); g.put(.basic, size: 0, u: 0.2, v: 0.14, degrees: 35, speed: 0) }),
      TourStep(title: "Snap the hinge", body: "Your secret weapon. Drag off the line and it cracks like a whip.",
               target: .hinge, todo: "Drag your finger off the glowing line.", done: "Bubbles near the line go flying. It dims while it recharges, so pick your moment.", input: true,
               waits: { $0.players[0].snaps >= 1 },
               scene: { _, g in g.put(.basic, size: 0, u: 0.25, v: 0.4, degrees: 35, speed: 0); g.put(.basic, size: 1, u: 0.75, v: 0.6, degrees: 35, speed: 0) }),
      TourStep(title: "Win shields back", body: "\(t.rechargeStreak) taps with no crossing wins a shield back.",
               target: .streak, before: { $0.players[0].shields = 2; $0.players[0].streak = 5 }),
      TourStep(title: "Score and combo", body: "Keep tapping to build your combo, up to x10.",
               target: .score, before: { $0.players[0].score = 1450; $0.players[0].combo = 3 }),
      TourStep(title: "Power-ups", body: "Tap these before they fade. Guest stars drop by too, so catch them!",
               target: .arena, scene: { _, g in
                 for (i, p) in PowerUp.allCases.enumerated() {
                   let across = g.vertical ? g.hinge * 0.45 : g.top + (g.hinge - g.top) * 0.5
                   let span = g.vertical ? g.h - g.top : g.w
                   let at = (g.vertical ? g.top : 0) + span * (Double(i) + 0.5) / 5
                   g.addPickup(p, x: g.vertical ? across : at, y: g.vertical ? at : across)
                 }
               }),
      TourStep(title: "You're ready", body: "Tap anything up top for details, any time.",
               target: .hud, last: "Play"),
    ]
  }
}

extension Session {
  var tourSteps: [TourStep] { TourScript.steps(tourKind) }

  func startTour(_ kind: TourKind) {
    tourKind = kind
    overlay = .tour
    #if DEBUG
    enterTour(Debug.int("-tourStep") ?? 0)
    #else
    enterTour(0)
    #endif
  }

  func enterTour(_ i: Int) {
    let list = tourSteps
    guard list.indices.contains(i) else { return }
    let step = list[i]
    tourIndex = i
    setTourGame(makeGame(tourKind == .versus ? .versus : .sandbox))
    game.flick = true
    game.graceOn = true
    game.clearScene()
    tourBubble = nil
    step.scene(self, game)
    step.before?(game)
    tourDone = step.waits == nil
    tourRun = step.live || (step.waits != nil && !step.input)
    tourInput = step.input
    tourClock = 0
    tourFreezeAt = 0
    tourNote = ""
  }

  func tickTour() {
    let step = tourSteps[tourIndex]
    if !tourDone, let retry = step.retry, retry(game) {
      let note = step.retryText ?? ""
      enterTour(tourIndex)
      tourNote = note
    } else if !tourDone, let waits = step.waits, waits(game) {
      tourDone = true
      tourInput = false
      tourRun = true
      tourFreezeAt = tourClock + 0.9
    } else if !tourDone, tourClock > 12 {
      // Nobody gets stuck on a gesture they cannot make.
      tourDone = true
      tourInput = false
    }
    if tourFreezeAt > 0, tourClock > tourFreezeAt { tourRun = false; tourFreezeAt = 0 }
  }

  func tourNext() {
    guard tourDone else { return }
    if tourIndex + 1 < tourSteps.count { enterTour(tourIndex + 1) } else { endTour() }
  }
  func tourBack() { if tourIndex > 0 { enterTour(tourIndex - 1) } }
  func endTour() {
    if tourKind == .versus { app.progress.seenVersusTour = true } else {
      app.progress.seenTour = true
      app.progress.taught.formUnion(["cross", "small", "shield", "recharge", "combo"])
    }
    startGame()
  }

  /// The spotlight's rectangle in the play view's coordinates.
  func spotRect(_ target: SpotTarget, hudFrames: [SpotTarget: CGRect]) -> (rect: CGRect, round: Bool, open: Bool)? {
    guard let g = game else { return nil }
    switch target {
    case .bubble:
      if let b = tourBubble, g.bubbles.contains(where: { $0 === b }) {
        let pad = 10.0
        return (CGRect(x: b.x - b.r - pad, y: b.y - b.r - pad, width: (b.r + pad) * 2, height: (b.r + pad) * 2), true, false)
      }
      return (CGRect(x: 0, y: g.top, width: g.w, height: g.h - g.top), false, true)
    case .hinge:
      let band = 44.0
      return (g.vertical ? CGRect(x: g.hinge - band / 2, y: g.top, width: band, height: g.h - g.top)
                         : CGRect(x: 0, y: g.hinge - band / 2, width: g.w, height: band), false, false)
    case .arena:
      return (CGRect(x: 0, y: g.top, width: g.w, height: g.h - g.top), false, true)
    default:
      return hudFrames[target].map { ($0.insetBy(dx: -6, dy: -6), false, false) }
    }
  }
}
