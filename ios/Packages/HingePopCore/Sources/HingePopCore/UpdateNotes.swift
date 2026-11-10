import Foundation

/// The "what's new" card shown once after an update. It reads the same release-notes/<version>.md that
/// becomes the TestFlight notes, so the two can't drift:
///   `# Hinge Pop 0.1.2: Headline`   the headline (text after the colon)
///   `## Bubble news`                1–4 callouts, each `- [sf.symbol] short line {destination}`
///   `## More`                       optional extra lines for the fold
/// The `{destination}` is optional: a callout with one gets a tap that closes the card and opens that place
/// (see `Destination`). An unknown destination is dropped, so the callout just stays plain.
public struct UpdateNotes: Equatable, Sendable {
  public struct Callout: Equatable, Sendable {
    public var symbol: String
    public var text: String
    public var destination: Destination? = nil
    public init(symbol: String, text: String, destination: Destination? = nil) {
      self.symbol = symbol; self.text = text; self.destination = destination
    }
  }

  /// Where a callout can take you. Written in the notes as `{map}`, `{guide}`, `{guide/duo}` (a How to play
  /// section's id), `{settings}`, `{play}` (the next level), `{arcade}`, `{daily}` or `{versus}`.
  public enum Destination: Equatable, Sendable {
    case map, settings, play, arcade, daily, versus
    case guide(section: String?)

    public init?(_ token: String) {
      let parts = token.trimmingCharacters(in: .whitespaces).split(separator: "/", maxSplits: 1).map(String.init)
      guard let place = parts.first else { return nil }
      let rest = parts.count > 1 ? parts[1] : nil
      if place == "guide" { self = .guide(section: rest); return }
      guard rest == nil else { return nil }
      switch place {
      case "map": self = .map
      case "settings": self = .settings
      case "play": self = .play
      case "arcade": self = .arcade
      case "daily": self = .daily
      case "versus": self = .versus
      default: return nil
      }
    }
  }
  public var version: String
  public var headline: String
  public var callouts: [Callout]
  public var more: [String]

  public static func parse(_ markdown: String, version: String) -> UpdateNotes? {
    var headline = "", section = "", callouts: [Callout] = [], more: [String] = []
    for raw in markdown.components(separatedBy: .newlines) {
      let line = raw.trimmingCharacters(in: .whitespaces)
      if line.hasPrefix("## ") { section = String(line.dropFirst(3)); continue }
      if line.hasPrefix("# ") {
        let title = String(line.dropFirst(2))
        headline = title.range(of: ": ").map { String(title[$0.upperBound...]) } ?? title
        section = ""
        continue
      }
      // A plain paragraph (like "Here's what to test:") ends the section, so tester notes stay out of the card.
      guard line.hasPrefix("- ") else { if !line.isEmpty { section = "" }; continue }
      let item = String(line.dropFirst(2))
      if section == "Bubble news", item.hasPrefix("["), let close = item.firstIndex(of: "]") {
        let symbol = String(item[item.index(after: item.startIndex)..<close])
        var text = item[item.index(after: close)...].trimmingCharacters(in: .whitespaces)
        var destination: Destination? = nil
        if text.hasSuffix("}"), let open = text.lastIndex(of: "{") {
          destination = Destination(String(text[text.index(after: open)..<text.index(before: text.endIndex)]))
          text = text[..<open].trimmingCharacters(in: .whitespaces)
        }
        if !symbol.isEmpty, !text.isEmpty { callouts.append(Callout(symbol: symbol, text: text, destination: destination)) }
      } else if section == "More" {
        more.append(item)
      }
    }
    guard !headline.isEmpty, !callouts.isEmpty else { return nil }
    return UpdateNotes(version: version, headline: headline, callouts: Array(callouts.prefix(4)), more: more)
  }

  /// Show once per version, and never on a fresh install: someone who has never played has nothing to update from.
  public static func shouldShow(seen: String?, current: String, playedBefore: Bool) -> Bool {
    guard let seen else { return playedBefore }
    return seen != current
  }

  /// The version to remember once the card closes. A forced card (the debug `-whatsNew` flag) never records,
  /// so forcing it on a phone leaves the real once-per-version gate untouched.
  public static func seenAfterClosing(seen: String?, shown: String, forced: Bool) -> String? {
    forced ? seen : shown
  }
}
