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
                 body: "The hinge splits the screen in two. The left player owns the left side, and the right player owns the right. Each of you has your own shields, meter and score at the top. On iPhone Duo, each player gets their own panel.",
                 target: .hinge, scene: { _, g in g.put(.basic, size: 0, u: 0.5, v: 0.2, degrees: 35, speed: 0); g.put(.basic, size: 0, u: 0.5, v: 0.8, degrees: 35, speed: 0) }),
        TourStep(title: "Stay on your side",
                 body: "A touch only reaches bubbles on the side it lands on, so you cannot steal your rival's bubbles. Both of you can tap at the same time.",
                 target: .arena, todo: "Tap a bubble.", done: "That point goes to whoever owns the side. The moves are the same as solo: tap to split, flick to aim.", input: true,
                 waits: { $0.players[0].taps + $0.players[1].taps >= 1 },
                 scene: { _, g in g.put(.basic, size: 0, u: 0.25, v: 0.2, degrees: 35, speed: 0); g.put(.basic, size: 0, u: 0.25, v: 0.8, degrees: 35, speed: 0) }),
        TourStep(title: "Crossings land on your rival",
                 body: "Watch this bubble leave the left side.",
                 target: .hinge, todo: "Watch the bubble.", done: "The left player paid a meter charge. The two pieces landed on the right, so the right player has more to clear, and more points to earn. A deliberate crossing piles on pressure, but it costs you.",
                 waits: { $0.players[0].crossings >= 1 },
                 scene: { _, g in g.put(.basic, size: 0, u: 0.45, v: 0.36, degrees: 60, speed: 0.8) }),
        TourStep(title: "Two ways to win",
                 body: "Take your rival's last shield and you win on the spot, whatever the score. If every bubble gets cleared first, the higher score wins. The smallest bubbles still pop free on the hinge, and the points go to the side they came from. Tap anything up top during a match for details.",
                 target: .hud, last: "Start match"),
      ]
    }
    return [
      TourStep(title: "Welcome to Hinge Pop",
               body: "Bubbles drift around the arena. This glowing line is the hinge. On iPhone Duo it sits right on the real fold. Your job is to clear every bubble while keeping the big ones off it. This takes about a minute, and you try each move for real.",
               target: .hinge, scene: { _, g in g.put(.basic, size: 0, u: 0.3, v: 0.2, degrees: 35, speed: 0); g.put(.basic, size: 1, u: 0.72, v: 0.28, degrees: 145, speed: 0) }),
      TourStep(title: "Tap to split", body: "A touch on any bubble splits it into two smaller ones.",
               target: .bubble, todo: "Tap the big bubble.", done: "One bubble became two, each a size smaller. You scored 100 points, and the pieces keep moving.", input: true,
               waits: { $0.players[0].taps >= 1 },
               scene: { s, g in s.tourBubble = g.put(.basic, size: 0, u: 0.5, v: 0.22, degrees: 35, speed: 0) }),
      TourStep(title: "Four sizes", body: "Bubbles go large, medium, small, smallest. Smaller ones move faster and score more per tap: 100, 200, 300 and 500. Tap the smallest and it pops for good. So one large bubble takes 15 taps to clear by hand.",
               target: .arena, scene: { _, g in for s in 0..<4 { g.put(.basic, size: s, u: 0.14 + Double(s) * 0.25, v: 0.22, degrees: 35, speed: 0) } }),
      TourStep(title: "Every bubble has its own weight", body: "Large bubbles are heavy and slow. The smallest are light, fast and very bouncy. When two bump, the lighter one takes most of the hit. Watch the big one knock the little one away. A shove can send a bubble into the hinge.",
               target: .arena, live: true, scene: { _, g in g.put(.basic, size: 0, u: 0.12, v: 0.2, degrees: 0); g.put(.basic, size: 3, u: 0.62, v: 0.2, degrees: 0, speed: 0) }),
      TourStep(title: "Swipe to slice", body: "You don't have to tap one at a time. One swipe hits every bubble it crosses, and the pieces fly the way you swiped. A faster swipe launches them harder, so you can steer them clear of the hinge.",
               target: .arena, todo: "Swipe across both bubbles in one stroke.", done: "One stroke, two splits, and the pieces went where you pointed. Swiping is how you keep up when the screen gets busy.", input: true,
               retryText: "That was a tap. This time, drag your finger across both bubbles.",
               retry: { $0.players[0].taps >= 1 && $0.players[0].flicks == 0 }, waits: { $0.players[0].flicks >= 2 },
               scene: { _, g in g.put(.basic, size: 1, u: 0.3, v: 0.24, degrees: 35, speed: 0); g.put(.basic, size: 1, u: 0.7, v: 0.24, degrees: 35, speed: 0) }),
      TourStep(title: "Chain pops", body: "Tiny bubbles set each other off. Pop one and every tiny bubble close to it pops too, and each link in the chain pays more.",
               target: .arena, todo: "Tap any tiny bubble in the bunch.", done: "One tap, the whole bunch. Let the tiny ones gather before you pop them, and magnetic bubbles will gather them for you.", input: true,
               waits: { $0.players[0].chained >= 1 },
               scene: { _, g in for (u, v) in [(0.4, 0.24), (0.47, 0.2), (0.54, 0.24), (0.47, 0.28), (0.6, 0.2)] { g.put(.basic, size: 3, u: u, v: v, degrees: 35, speed: 0) } }),
      TourStep(title: "The hinge bites", body: "Now watch what happens when a larger bubble reaches the hinge.", target: .hinge, todo: "Watch the bubble.",
               done: "It split for free, but you pay for it: no points, your combo resets, and the overload meter gains a charge. Sometimes that is still worth it when you have too much to handle.",
               waits: { $0.players[0].crossings >= 1 }, scene: { _, g in g.put(.basic, size: 0, u: 0.3, v: 0.34, degrees: 70, speed: 0.8) }),
      TourStep(title: "The overload meter", body: "This is the meter. Each crossing fills one of its \(t.meterMax) segments, and the hinge turns from blue to violet to red as it fills. When the last segment fills, you lose a shield and the meter empties. It shows 2 of \(t.meterMax) as an example.",
               target: .meter, before: { $0.players[0].meter = 2 }),
      TourStep(title: "Shields", body: "You start each level with \(t.shields) shields. Lose the last one and the level starts again, with your score back to where it began. It shows 2 of \(t.shields) as an example.",
               target: .shields, before: { $0.players[0].shields = 2 }),
      TourStep(title: "The hinge helps with the smallest", body: "Here is the good news. Watch the smallest bubble reach the hinge.", target: .hinge, todo: "Watch the bubble.",
               done: "It popped for a flat 500 points, and the meter, combo and streak did not change. So leave the smallest ones to the hinge, or even aim them at it. Tapping one scores more, because the combo multiplies it.",
               waits: { $0.players[0].zaps >= 1 }, scene: { _, g in g.put(.basic, size: 3, u: 0.5, v: 0.36, degrees: 70, speed: 0.5); g.put(.basic, size: 0, u: 0.2, v: 0.14, degrees: 35, speed: 0) }),
      TourStep(title: "Win shields back", body: "This thin bar is your streak. Tap \(t.rechargeStreak) times in a row with no crossing and you win back a lost shield. At full shields, the streak clears the meter instead. Any crossing empties the bar. It shows 5 of \(t.rechargeStreak) as an example.",
               target: .streak, before: { $0.players[0].shields = 2; $0.players[0].streak = 5 }),
      TourStep(title: "Score and combo", body: "Each tap multiplies a bubble's points by your combo. Every tap adds x0.5, up to x10. It ends if \(String(format: "%.1f", t.comboWindow)) seconds pass with no tap, or on any crossing. Clear a level with no crossings for a 25% bonus.",
               target: .score, before: { $0.players[0].score = 1450; $0.players[0].combo = 3 }),
      TourStep(title: "Power-ups", body: "Popping bubbles sometimes drops a power-up. Tap it before it fades. There are five: Overcharge, Freeze, Focus, Shield and Chain Burst. The first time you pick up each one, the game tells you what it does.",
               target: .arena, scene: { _, g in
                 for (i, p) in PowerUp.allCases.enumerated() {
                   let across = g.vertical ? g.hinge * 0.45 : g.top + (g.hinge - g.top) * 0.5
                   let span = g.vertical ? g.h - g.top : g.w
                   let at = (g.vertical ? g.top : 0) + span * (Double(i) + 0.5) / 5
                   g.addPickup(p, x: g.vertical ? across : at, y: g.vertical ? at : across)
                 }
               }),
      TourStep(title: "Help is always here", body: "During play, tap the shields, the meter or the score for a full explanation with your live numbers. The game holds still while you read. New kinds of bubble introduce themselves when they first appear, and the Bubble Guide on the home screen lists them all.",
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
