import Foundation

/// Easter eggs. Every one is an original wink at a pop-culture genre: no real names, characters, logos or quotes.
public struct Secret: Equatable, Sendable, Identifiable {
  public var id: String
  public var emoji: String
  public var title: String
  public var line: String
  public var hint: String
}

public enum SecretSwipe: Sendable, Equatable { case up, down, left, right }

public enum Secrets {
  /// The named secrets, each found once.
  public static let named: [Secret] = [
    .init(id: "classic-star", emoji: "🌠", title: "Shooting star", line: "Make a wish. It's a pop.", hint: "Tap the low bright star three times."),
    .init(id: "neon-cruise", emoji: "🏎️", title: "Grid runner", line: "A retro coupe cruises the neon grid. Top speed, no brakes.", hint: "Knock on the setting sun."),
    .init(id: "forest-howl", emoji: "🐺", title: "Full moon", line: "Full moon. Fuller combo.", hint: "Knock on the big oak under the moon."),
    .init(id: "space-saucer", emoji: "🛸", title: "Close encounter", line: "We come in peace. Mostly to pop.", hint: "Knock on the ringed planet."),
    .init(id: "frost-tracks", emoji: "👣", title: "Big feet", line: "Huge footprints in the snow. Someone loves bubbles.", hint: "Something hides by the tallest fir."),
    .init(id: "reef-treasure", emoji: "🪙", title: "Sunken treasure", line: "X never marks the spot. Taps do.", hint: "The coral keeps a secret."),
    .init(id: "magma-lair", emoji: "🐈‍⬛", title: "Volcano lair", line: "Every volcano lair needs a cat to pet menacingly.", hint: "Knock on the tallest volcano."),
    .init(id: "answer", emoji: "🌌", title: "The answer", line: "Level 42. The answer was pop all along.", hint: "Clear a very meaningful level."),
    .init(id: "cheat-code", emoji: "🕹️", title: "Old-school code", line: "Up, up, down, down... the arcade remembers.", hint: "Some codes never die. Swipe them on the logo."),
    .init(id: "witching", emoji: "🦇", title: "Witching hour", line: "Popping at 3 a.m.? Bold.", hint: "Play when the clock strikes three."),
    .init(id: "spooky", emoji: "🎃", title: "Spooky season", line: "Boo! The bubbles dressed up.", hint: "Play on the last day of October."),
    .init(id: "new-year", emoji: "🎆", title: "New year", line: "New year, new pops.", hint: "Play on the first day of the year."),
    .init(id: "pi-day", emoji: "🥧", title: "Pi day", line: "3.14 pops and counting.", hint: "Play on the fourteenth of March."),
    .init(id: "full-cast", emoji: "🎬", title: "Full ensemble", line: "Every guest star caught. Roll credits.", hint: "Catch every guest star."),
    .init(id: "ovation", emoji: "👏", title: "Standing ovation", line: "Three claps in one level. The crowd stands.", hint: "On iPhone Duo, clap the crease three times in one level."),
    .init(id: "max-combo", emoji: "🔟", title: "Max combo", line: "Ten times. The crowd goes wild.", hint: "Push a combo all the way."),
    .init(id: "million", emoji: "💰", title: "Millionaire", line: "Seven digits. Very fancy.", hint: "Score a million."),
  ]

  public static func named(_ id: String) -> Secret? { named.first { $0.id == id } }

  /// Genre nods for the secret bubble hidden in every level from 2 on. They cycle, so they never run out.
  public static let nods: [String] = [
    "Heist night: pop everything, leave no bubble behind.",
    "A giant bubble rises from the bay. The city sighs and gets the broom.",
    "In a galaxy of bubbles, you were always the chosen popper.",
    "It was the quiet bubble. It's always the quiet bubble.",
    "Arr. The treasure was the pops we made along the way.",
    "Beep boop. Pop pop. Robot approved.",
    "Old bones, new pops. The museum is closed for the night.",
    "Braaains? No thanks. Bubbles.",
    "This hinge ain't big enough for the two of us.",
    "Your future self says: duck.",
    "The bubbles are coming from inside the screen.",
    "Nobody believed in this bubble. Except you.",
    "Yes, chef. Pop, chef.",
    "Five bubbles, one harmony, zero dance breaks skipped.",
    "And they popped happily ever after.",
    "Agent Bubble, your mission: stay off the line.",
    "The prophecy spoke of a tap. This was that tap.",
    "Previously, on Hinge Pop: absolutely everything.",
    "Plot twist: the bubble was inside you all along.",
    "Montage music swells. You get very good at popping.",
    "Spellbook says: point, tap, sparkle.",
    "Roll for initiative. You rolled a pop.",
    "Fourth wall check: still there? Pop it.",
    "Insert coin to continue. Just kidding, it's free.",
    "High score unlocked. The arcade is proud of you.",
    "Cue the dramatic slow-motion pop.",
    "Somewhere, a narrator just said: little did they know.",
    "The sequel is always bigger. So are the bubbles.",
    "Breaking news: local hero pops bubble, crowd goes mild.",
    "Weather update: scattered bubbles, clearing by level end.",
    "The heist crew needed a popper. They called you.",
    "Lights, camera, pop!",
    "Space is big. This bubble is not.",
    "A lone bubble drifts into town at high noon.",
    "The castle had one rule: never pop after midnight. Oops.",
    "Haunted? No. Just very bubbly.",
    "The dragon hoards bubbles. You just stole one.",
    "Training montage complete. You are ready.",
    "Credits roll... but wait, there's a scene after.",
    "Mission control confirms: clean pop on the far side.",
    "The detective adjusts her hat. Case closed.",
    "Kaiju alert downgraded to bubble alert.",
    "Underdog story: level one bubble, level ninety-nine legend.",
    "The mixtape had one track: pop.",
    "Synth solo! The grid lights up.",
    "Out of the fog sails a ship made of soap.",
    "Dino-mite. Sorry.",
    "Cheat code accepted. Just kidding, you earned it.",
  ]

  /// The nod hidden in a level. The same level always hides the same one.
  public static func nod(level: Int) -> String { nods[(max(1, level) * 7) % nods.count] }

  /// Where each world hides its secret, in fractions of the backdrop: centre and radius (of the short side).
  /// These follow the art in HingePopArt/Arenas.swift.
  public static func spot(_ arena: Arena, width w: Double, height h: Double) -> (x: Double, y: Double, r: Double) {
    let u = min(w, h)
    switch arena {
    case .classic: return (w * 0.14, min(h * 0.92, h - u * 0.1), u * 0.13)
    case .neon: return (w * 0.5, h - max(u * 0.30, h * 0.20), u * 0.22)
    case .forest: return (w * 0.93, h - max(u * 0.26, h * 0.16) - u * 0.12, u * 0.16)
    case .space: return (w * 0.80, h * 0.87, u * 0.17)
    case .frost: return (w * 0.85, h - max(u * 0.26, h * 0.16) - u * 0.15, u * 0.15)
    case .reef: return (w * 0.08, h - max(u * 0.2, h * 0.12) - u * 0.1, u * 0.16)
    case .magma: return (w * 0.97, h - max(u * 0.3, h * 0.2) - u * 0.38, u * 0.14)
    }
  }

  public static func spotSecret(_ arena: Arena) -> Secret {
    named("\(arena.rawValue)-" + ["classic": "star", "neon": "cruise", "forest": "howl", "space": "saucer", "frost": "tracks", "reef": "treasure", "magma": "lair"][arena.rawValue, default: ""])!
  }

  /// A date or hour that hides something.
  public static func calendar(month: Int, day: Int, hour: Int) -> [Secret] {
    var out: [Secret] = []
    if hour == 3 { out.append(named("witching")!) }
    if month == 10 && day == 31 { out.append(named("spooky")!) }
    if month == 1 && day == 1 { out.append(named("new-year")!) }
    if month == 3 && day == 14 { out.append(named("pi-day")!) }
    return out
  }

  /// The old arcade code, swiped.
  public static let code: [SecretSwipe] = [.up, .up, .down, .down, .left, .right, .left, .right]
  /// True when the last swipes spell the code.
  public static func spells(_ swipes: [SecretSwipe]) -> Bool { swipes.suffix(code.count).elementsEqual(code) }
}
