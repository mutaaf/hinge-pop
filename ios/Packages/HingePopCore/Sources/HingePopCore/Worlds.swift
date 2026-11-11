import Foundation

/// A world's twist: one rule that changes how its ten levels play. Every twist is a level-wide modifier
/// (it never changes what a tap does to a bubble's size), so the core rules and the balance bots still apply.
public enum Twist: String, CaseIterable, Sendable, Codable {
  /// Pushes everything along the hinge, turning around every `currentPeriod` (Coral Drift's original twist).
  case current
  /// Gusts push bubbles across, toward the hinge, then ease off.
  case wind
  /// The hinge itself rises and falls slowly, so the line you guard moves.
  case tide
  /// Bubbles far from the hinge fade out; they show again as they come near.
  case fog
  /// Bubbles blink out of phase for a moment now and then; a phased bubble can't be tapped and can't cross.
  case ghost
  /// A few gravity wells pull nearby bubbles into slow orbits.
  case wells
  /// The side walls are portals: a bubble that reaches one comes out of the other.
  case portals
  /// The walls are springy: each bounce adds a little speed, up to a cap.
  case bounce
  /// An untouched piece slowly grows back one size, so leaving smalls alone has a cost.
  case regrow
  /// Splits make three pieces, not two, each a little lighter on the meter.
  case triple
  /// The world beats on a rhythm; a pop on the beat scores double and adds an extra combo step.
  case pulse
  /// Lights out: you see the arena near the hinge and around your finger, and bubbles glow as they come close.
  case blackout
}

/// How a world's boss fights. `crown` is the original boss; the rest change its pattern, never its hit rules.
public enum BossStyle: String, CaseIterable, Sendable, Codable {
  case crown      // the original: guards after hits, telegraphs a dash
  case twins      // two smaller bosses that share one health bar
  case shielded   // an orbiting shield blocks one side; hit it from the open side
  case splitter   // at each new phase it splits off a fast minion
  case blinker    // teleports to a new spot instead of dashing
  case summoner   // calls in a small wave of basics at each phase
}

/// One world: a backdrop (its biome and a variant of it), a twist, a boss and ten levels.
public struct World: Sendable, Equatable {
  public var number: Int          // 1...80, also its chapter number
  public var realm: Int           // 1...10
  public var name: String
  public var biome: Arena
  /// Which take on the biome's art this world uses (0 is the original; 1–3 shift time of day and palette).
  public var variant: Int
  public var twists: [Twist]
  public var boss: BossStyle
  public var teaches: String
  public var levels: ClosedRange<Int> { ((number - 1) * 10 + 1)...(number * 10) }
}

public struct Realm: Sendable, Equatable {
  public var number: Int
  public var name: String
  /// The genre this realm winks at. Original nods only: no real titles, characters or quotes.
  public var nod: String
  public var home: Arena
  public var worlds: ClosedRange<Int> { ((number - 1) * 8 + 1)...(number * 8) }
}

public enum Worlds {
  public static let realms: [Realm] = [
    .init(number: 1, name: "Home Stretch", nod: "Saturday-morning arcade", home: .classic),
    .init(number: 2, name: "Sugar Rush", nod: "Candy-coloured cartoons", home: .candy),
    .init(number: 3, name: "Dune Sea", nod: "Desert epics", home: .dunes),
    .init(number: 4, name: "Thunderhead", nod: "Caped heroes and storm gods", home: .storm),
    .init(number: 5, name: "Crystal Deep", nod: "Quest fantasy", home: .crystal),
    .init(number: 6, name: "Night Manor", nod: "Haunted houses and monster movies", home: .haunted),
    .init(number: 7, name: "Circuit City", nod: "Neon noir, heists and arcades", home: .circuit),
    .init(number: 8, name: "Wild Temple", nod: "Treasure-hunting serials", home: .jungle),
    .init(number: 9, name: "Cloud Kingdom", nod: "Fairy tales and sky castles", home: .clouds),
    .init(number: 10, name: "Clockwork Sky", nod: "Steampunk and time travel", home: .clockwork),
  ]

  // name, biome, variant, twists, boss, teaches
  private typealias Row = (String, Arena, Int, [Twist], BossStyle, String)

  private static let rows: [Row] = [
    // 1 Home Stretch: the original eight chapters.
    ("First Contact", .classic, 0, [], .crown, "Pop and split, then faster bubbles."),
    ("Electric Playground", .neon, 0, [], .crown, "Armored bubbles and a touchier hinge."),
    ("Magnetic Storm", .forest, 0, [], .crown, "Magnetic and repel bubbles move everything around them."),
    ("Overload Protocol", .space, 0, [], .crown, "Moving gates and mixed bubbles."),
    ("Bosses & Beyond", .neon, 0, [], .crown, "Boss patterns and combos."),
    ("Frost Fair", .frost, 0, [], .crown, "Frozen crowds and a shorter meter."),
    ("Coral Drift", .reef, 0, [.current], .crown, "A current pushes everything along the hinge."),
    ("Magma Run", .magma, 0, [], .crown, "Fast and golden, with a boss halfway."),
    // 2 Sugar Rush
    ("Gumdrop Gulch", .candy, 0, [.bounce], .twins, "Springy walls speed bubbles up."),
    ("Taffy Twister", .candy, 1, [.current], .crown, "Sticky currents stretch along the line."),
    ("Sprinkle Squall", .candy, 2, [.wind], .splitter, "Gusts shove bubbles at the hinge."),
    ("Licorice Loop", .candy, 3, [.portals], .blinker, "Off one wall, out the other."),
    ("Fizz Pop Falls", .reef, 1, [.triple], .summoner, "Every split makes three."),
    ("Cocoa Caverns", .crystal, 1, [.fog], .shielded, "Bubbles hide until they're close."),
    ("Marshmallow Moon", .space, 1, [.bounce, .regrow], .twins, "Leave a small too long and it grows."),
    ("Sugar Crash", .candy, 0, [.pulse, .wind], .summoner, "Pop on the beat for double."),
    // 3 Dune Sea
    ("Mirage Mile", .dunes, 0, [.ghost], .blinker, "Bubbles shimmer out of reach."),
    ("Sandworm Shallows", .dunes, 1, [.tide], .crown, "The line rises and falls."),
    ("Oasis Run", .dunes, 2, [.current], .twins, "The current runs toward the water."),
    ("Sunstone Spire", .dunes, 3, [.wind], .splitter, "Desert gusts, harder every level."),
    ("Scarab Bazaar", .jungle, 1, [.portals], .blinker, "Shortcuts through the market walls."),
    ("Glass Desert", .crystal, 2, [.bounce], .shielded, "Sand turned to glass, and everything bounces."),
    ("Twin Suns", .dunes, 0, [.pulse], .twins, "Two suns, one rhythm."),
    ("Spice Wind", .dunes, 1, [.wind, .ghost], .summoner, "Gusts and mirages together."),
    // 4 Thunderhead
    ("Static Summit", .storm, 0, [.wells], .crown, "Charged wells pull bubbles into orbit."),
    ("Bolt Alley", .storm, 1, [.pulse], .blinker, "Strike with the thunder."),
    ("Cape Gale", .storm, 2, [.wind], .splitter, "Hold the line in a hero's headwind."),
    ("Hammerfall Heights", .storm, 3, [.tide], .shielded, "The hinge heaves like a storm sea."),
    ("Lightning Lab", .circuit, 1, [.wells], .summoner, "Coils that drag everything in."),
    ("Eye of the Storm", .storm, 0, [.current], .twins, "The calm moves; the current circles."),
    ("Hero Landing", .clouds, 1, [.bounce], .crown, "Land hard, bounce harder."),
    ("Storm Crown", .storm, 1, [.triple, .wind], .summoner, "Three-way splits in a gale."),
    // 5 Crystal Deep
    ("Gem Hollow", .crystal, 0, [.regrow], .crown, "Crystals grow back if you let them."),
    ("Prism Mines", .crystal, 1, [.portals], .blinker, "Light bends; so do the walls."),
    ("Echo Grotto", .crystal, 2, [.ghost], .twins, "Echoes blink in and out."),
    ("Dragon's Hoard", .magma, 1, [.wells], .shielded, "Gold piles pull everything close."),
    ("Mirror Lake", .frost, 1, [.portals, .bounce], .splitter, "Bounce off the walls, out the other side."),
    ("Rune Depths", .crystal, 3, [.fog], .summoner, "Only the runes near the line glow."),
    ("Quest Road", .forest, 1, [.regrow, .current], .crown, "The road carries you; the smalls grow back."),
    ("Crown Cavern", .crystal, 0, [.wells, .pulse], .summoner, "The hoard's heart beats."),
    // 6 Night Manor
    ("Creaky Foyer", .haunted, 0, [.ghost], .blinker, "Bubbles that aren't always there."),
    ("Cobweb Attic", .haunted, 1, [.fog], .crown, "Dust hides the far side."),
    ("Moonlit Moor", .forest, 2, [.blackout], .twins, "Lights out on the moor."),
    ("Organ Hall", .haunted, 2, [.pulse], .summoner, "Pop to the organ's beat."),
    ("Wrapped Wing", .dunes, 2, [.regrow], .shielded, "What you leave unwrapped comes back."),
    ("Midnight Lab", .circuit, 2, [.wells], .splitter, "Sparking coils and odd experiments."),
    ("Graveyard Shift", .haunted, 3, [.blackout, .ghost], .blinker, "Dark, and things flicker."),
    ("Masquerade", .haunted, 0, [.triple, .pulse], .summoner, "The last dance splits three ways."),
    // 7 Circuit City
    ("Neon Noir", .circuit, 0, [.blackout], .crown, "Rain, neon, and not much light."),
    ("Pixel Plaza", .circuit, 1, [.pulse], .twins, "Pop to the chiptune."),
    ("Data Stream", .circuit, 2, [.current], .splitter, "Packets flow along the line."),
    ("Heist Hour", .circuit, 3, [.portals], .blinker, "In one wall, out the other, before the alarm."),
    ("Glitch Garden", .neon, 1, [.ghost], .shielded, "Bubbles glitch out of phase."),
    ("Hover Highway", .neon, 2, [.wind], .twins, "Traffic gusts across the hinge."),
    ("Mainframe", .circuit, 0, [.wells], .summoner, "Data wells pull bubbles into orbit."),
    ("High Score Tower", .circuit, 1, [.triple, .bounce], .summoner, "Splits and bounces for the top score."),
    // 8 Wild Temple
    ("Vine Swing", .jungle, 0, [.tide], .crown, "The hinge swings like a vine."),
    ("Idol Run", .jungle, 1, [.bounce], .blinker, "The temple walls bounce back."),
    ("Rolling Rock", .jungle, 2, [.wind], .splitter, "Something big is rolling your way."),
    ("Lost Valley", .jungle, 3, [.regrow], .twins, "Things grow big here."),
    ("Snake Pit", .jungle, 2, [.fog], .shielded, "Watch the shadows near the line."),
    ("Waterfall Vault", .reef, 2, [.current], .crown, "The falls pull everything one way."),
    ("Lava Bridge", .magma, 2, [.tide], .splitter, "The bridge rocks over the lava."),
    ("Golden Idol", .jungle, 0, [.triple, .pulse], .summoner, "The idol's chamber beats."),
    // 9 Cloud Kingdom
    ("Beanstalk Climb", .clouds, 0, [.tide], .crown, "The stalk sways; so does the line."),
    ("Castle in the Air", .clouds, 1, [.wind], .twins, "High winds round the towers."),
    ("Prism Bridge", .clouds, 2, [.bounce], .blinker, "A bridge of light that bounces."),
    ("Giant's Kitchen", .clouds, 3, [.regrow], .shielded, "Leftovers grow giant."),
    ("Wishing Well", .clouds, 0, [.wells], .splitter, "Wells that pull wishes in."),
    ("Glass Slipper Ball", .crystal, 3, [.pulse], .twins, "Dance before the clock strikes."),
    ("Storm Wall", .storm, 2, [.wind, .fog], .summoner, "The kingdom's edge, in cloud and gale."),
    ("Starfall Spires", .clouds, 1, [.portals, .ghost], .summoner, "Falling stars through every wall."),
    // 10 Clockwork Sky
    ("Gear Garden", .clockwork, 0, [.current], .crown, "Gears turn the current."),
    ("Steam Docks", .clockwork, 1, [.wind], .twins, "Steam vents blast across the line."),
    ("Time Loop", .clockwork, 2, [.portals], .blinker, "Out one side, in the other, again."),
    ("Pendulum Hall", .clockwork, 3, [.tide], .shielded, "The line swings like a pendulum."),
    ("Airship Armada", .clouds, 2, [.wind, .bounce], .splitter, "Gusts between the hulls."),
    ("Tick Tock Tower", .clockwork, 0, [.pulse], .summoner, "Pop on the tick."),
    ("Paradox Point", .clockwork, 1, [.ghost, .portals], .blinker, "Here, gone, and somewhere else."),
    ("The Last Second", .clockwork, 2, [.triple, .blackout], .summoner, "The final world. Lights out, three-way splits."),
  ]

  public static let all: [World] = rows.enumerated().map { i, r in
    World(number: i + 1, realm: i / 8 + 1, name: r.0, biome: r.1, variant: r.2, twists: r.3, boss: r.4, teaches: r.5)
  }

  public static var count: Int { all.count }

  public static func world(_ number: Int) -> World? { (1...all.count).contains(number) ? all[number - 1] : nil }
  public static func realm(_ number: Int) -> Realm? { (1...realms.count).contains(number) ? realms[number - 1] : nil }
  public static func world(ofLevel level: Int) -> World? { world((max(1, level) - 1) / 10 + 1) }
}
