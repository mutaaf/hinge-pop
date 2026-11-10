import Foundation

/// The "what's new" card shown once after an update. It reads the same release-notes/<version>.md that
/// becomes the TestFlight notes, so the two can't drift:
///   `# Hinge Pop 0.1.2: Headline`   the headline (text after the colon)
///   `## Bubble news`                1–4 callouts, each `- [sf.symbol] short line`
///   `## More`                       optional extra lines for the fold
public struct UpdateNotes: Equatable, Sendable {
  public struct Callout: Equatable, Sendable {
    public var symbol: String
    public var text: String
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
        let text = item[item.index(after: close)...].trimmingCharacters(in: .whitespaces)
        if !symbol.isEmpty, !text.isEmpty { callouts.append(Callout(symbol: symbol, text: text)) }
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
}
