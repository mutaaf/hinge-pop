import SwiftUI
import HingePopArt
import HingePopCore

// The end of a run. A clear stamps a grade, ticks its challenges in one by one and offers a quick retry for
// the S. A loss says what went wrong in a few words and puts Retry first, because hard games need a fast way back.

extension Grade {
  /// The stamp's colours: S burns gold, A is cool cyan, the rest fade toward violet and grey.
  var colors: [Color] {
    switch self {
    case .s: [Color(red: 1, green: 0.93, blue: 0.45), Theme.orange]
    case .a: [Color(red: 0.6, green: 0.95, blue: 1), Theme.cyan]
    case .b: [Color(red: 0.85, green: 0.75, blue: 1), Theme.violet]
    case .c: [Color(red: 0.8, green: 0.78, blue: 0.9), Color(red: 0.5, green: 0.46, blue: 0.68)]
    case .d: [Color(red: 0.62, green: 0.6, blue: 0.7), Color(red: 0.36, green: 0.33, blue: 0.48)]
    }
  }
  var glow: Color { colors[1] }
}

/// A grade, as a stamped badge. `stamped` drives the slam-down.
struct GradeStamp: View {
  let grade: Grade
  var size: CGFloat = 92
  var stamped = true
  var body: some View {
    let c = grade.colors
    ZStack {
      Circle().fill(LinearGradient(colors: c, startPoint: .top, endPoint: .bottom))
      Circle().fill(.white.opacity(0.28)).frame(width: size * 0.62, height: size * 0.26).offset(y: -size * 0.27)
      Circle().stroke(.white.opacity(0.9), lineWidth: max(2, size * 0.035)).padding(size * 0.07)
      Circle().stroke(.black.opacity(0.25), lineWidth: 1)
      Text(grade.letter)
        .font(.system(size: size * 0.58, weight: .black, design: .rounded))
        .foregroundStyle(Color(red: 0.16, green: 0.06, blue: 0.2))
        .shadow(color: .white.opacity(0.5), radius: 1, y: 1)
    }
    .frame(width: size, height: size)
    .shadow(color: grade.glow.opacity(grade == .s ? 0.95 : 0.55), radius: grade == .s ? 18 : 9)
    .rotationEffect(.degrees(stamped ? -8 : -24))
    .scaleEffect(stamped ? 1 : 2.3)
    .opacity(stamped ? 1 : 0)
    .accessibilityElement()
    .accessibilityLabel("Grade \(grade.letter)")
    .accessibilityIdentifier("grade")
  }
}

/// A level's three challenges as little pips: lit when earned.
struct ChallengePips: View {
  let done: [Bool]
  var size: CGFloat = 7
  var body: some View {
    HStack(spacing: size * 0.55) {
      ForEach(done.indices, id: \.self) { i in
        Circle()
          .fill(done[i] ? AnyShapeStyle(LinearGradient(colors: [.white, Theme.sun], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(Color.white.opacity(0.18)))
          .overlay(Circle().stroke(done[i] ? Theme.sun : .white.opacity(0.45), lineWidth: 1))
          .frame(width: size, height: size)
          .shadow(color: done[i] ? Theme.sun.opacity(0.8) : .clear, radius: 3)
      }
    }
    .accessibilityHidden(true)
  }
}

/// One challenge on the card. New ones glow and say so.
struct ChallengeRow: View {
  enum State { case new, had, missed }
  let challenge: Challenge
  let state: State
  var shown = true
  var compact = false
  var body: some View {
    let lit = state != .missed && shown
    HStack(spacing: 10) {
      ZStack {
        Circle().fill(lit ? AnyShapeStyle(LinearGradient(colors: [Color(red: 1, green: 0.9, blue: 0.45), Theme.orange], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(Color.white.opacity(0.08)))
        Circle().stroke(lit ? .white.opacity(0.85) : .white.opacity(0.3), lineWidth: 1.5)
        Image(systemName: lit ? "checkmark" : challenge.symbol)
          .font(.system(size: compact ? 12 : 15, weight: .black))
          .foregroundStyle(lit ? Color(red: 0.2, green: 0.08, blue: 0.1) : Theme.muted)
      }
      .frame(width: compact ? 26 : 34, height: compact ? 26 : 34)
      .scaleEffect(state == .new && shown ? 1 : (shown ? 1 : 0.6))
      .shadow(color: state == .new && shown ? Theme.sun.opacity(0.9) : .clear, radius: 8)
      Text(challenge.title)
        .font(.game(compact ? .footnote : .subheadline, .heavy))
        .foregroundStyle(lit ? Theme.ink : Theme.muted)
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)
        .layoutPriority(1)
      Spacer(minLength: 4)
      if state == .new && shown {
        Text("NEW").font(.game(.caption2, .black)).tracking(1.2)
          .foregroundStyle(Color(red: 0.2, green: 0.08, blue: 0.1))
          .padding(.horizontal, 7).padding(.vertical, 3)
          .background(Capsule().fill(Theme.sun))
          .transition(.scale.combined(with: .opacity))
      } else if !compact {
        Image(systemName: challenge.symbol).font(.system(size: 13, weight: .bold)).foregroundStyle(lit ? Theme.sun : Theme.muted.opacity(0.6))
      }
    }
    .padding(.horizontal, compact ? 8 : 10).padding(.vertical, compact ? 4 : 6)
    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(state == .new && shown ? Theme.sun.opacity(0.14) : .white.opacity(0.04)))
    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(state == .new && shown ? Theme.sun.opacity(0.6) : .clear, lineWidth: 1))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(challenge.title), \(state == .new ? "done, new" : state == .had ? "done" : "not yet")")
  }
}

struct ResultOverlay: View {
  @Environment(AppModel.self) private var app
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let session: Session
  @State private var shown = 0
  @State private var starsIn = 0
  @State private var stamped = false
  @State private var ticked = 0
  @State private var settled = false
  @State private var details: String? = nil

  private var won: Bool { session.game.status == .won }

  var body: some View {
    let g = session.game!
    Centered {
      Sheet(maxWidth: 460) {
        if case .campaign(let n) = session.mode {
          if won { winCard(g, level: n) } else { loseCard(g, level: n) }
        } else {
          otherCard(g)
        }
        Fold(title: "Details", id: "stats", open: $details) { StatGrid(session: session) }
      }
    }
    .task { await play(g) }
  }

  // MARK: Campaign: a clear

  @ViewBuilder private func winCard(_ g: Game, level n: Int) -> some View {
    let grade = session.grade ?? .d
    AuroraSpot(arena: session.arena) {
      VStack(spacing: 8) {
        HStack(alignment: .center, spacing: 12) {
          VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
              Text("LEVEL \(n)").font(.game(.caption, .heavy)).tracking(2).foregroundStyle(.white.opacity(0.9))
              if g.difficulty == .overdrive { OverdriveTag(big: true) }
            }
            Text("Cleared!").font(.game(.title, .black)).foregroundStyle(.white)
            HStack(spacing: 4) {
              ForEach(0..<3, id: \.self) { i in
                if i < starsIn { AuroraAssemble(item: .glyph(.starOn), size: 34, count: 160) }
                else { ArtImage(item: .glyph(.starOff), size: 34) }
              }
            }
            .accessibilityElement().accessibilityLabel("\(g.stars) of 3 stars")
          }
          Spacer(minLength: 0)
          GradeStamp(grade: grade, size: 96, stamped: stamped)
        }
        Text(shown.formatted())
          .font(.system(size: 46, weight: .black, design: .rounded))
          .monospacedDigit()
          .foregroundStyle(LinearGradient(colors: [.white, Theme.sun], startPoint: .top, endPoint: .bottom))
          .contentTransition(.numericText(value: Double(shown)))
          .minimumScaleFactor(0.6).lineLimit(1)
          .frame(maxWidth: .infinity, alignment: .leading)
        let notes = winNotes(g)
        if !notes.isEmpty {
          HStack(spacing: 6) {
            ForEach(notes, id: \.self) { note in
              Text(note).font(.game(.caption, .heavy)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.8)
                .padding(.horizontal, 9).padding(.vertical, 4)
                .background(Capsule().fill(.black.opacity(0.45)))
                .overlay(Capsule().stroke(Theme.sun.opacity(0.7), lineWidth: 1))
            }
            Spacer(minLength: 0)
          }
          .opacity(settled ? 1 : 0)
        }
      }
      .padding(16)
      .frame(maxWidth: .infinity)
    }
    VStack(spacing: 6) {
      ForEach(Array(session.challenges.enumerated()), id: \.offset) { i, c in
        ChallengeRow(challenge: c, state: state(i), shown: ticked > i)
          .animation(reduceMotion ? nil : .spring(duration: 0.35, bounce: 0.45), value: ticked)
      }
    }
    if let world = session.news.medal, let w = Worlds.world(world) {
      HStack(spacing: 10) {
        Image(systemName: "medal.fill").font(.system(size: 26, weight: .bold)).foregroundStyle(Theme.sun)
        VStack(alignment: .leading, spacing: 1) {
          Text("\(w.name) medal!").font(.game(.headline, .black)).foregroundStyle(Theme.ink)
          Text("New \(w.biome.backdropName) trail in Settings").font(.game(.footnote, .semibold)).foregroundStyle(Theme.muted)
        }
        Spacer(minLength: 0)
      }
      .padding(10)
      .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.sun.opacity(0.14)))
      .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.sun, lineWidth: 1.5))
      .opacity(settled ? 1 : 0)
    }
    if let line = gateLine(level: n) {
      Text(line).font(.game(.footnote, .semibold)).foregroundStyle(Theme.muted).frame(maxWidth: .infinity).multilineTextAlignment(.center)
    }
    winActions(level: n, grade: grade)
  }

  private func state(_ i: Int) -> ChallengeRow.State {
    if session.news.newChallenges.indices.contains(i), session.news.newChallenges[i] { return .new }
    if case .campaign(let n) = session.mode, app.progress.challengesDone(n).indices.contains(i), app.progress.challengesDone(n)[i] { return .had }
    return .missed
  }

  private func winNotes(_ g: Game) -> [String] {
    var parts: [String] = []
    if session.news.firstOverdrive { parts.append("🔥 Overdrive clear!") }
    if session.news.bestGrade { parts.append("Best grade!") }
    if session.resultWasBest { parts.append("New best!") }
    if g.cleanBonus { parts.append("Clean +25%") }
    if session.grade != .s && session.par > 0 { parts.append("S at \(Self.short(session.par))") }
    return Array(parts.prefix(3))
  }

  /// 125,000 reads as 125k on a chip.
  static func short(_ n: Int) -> String {
    n >= 10_000 ? "\(n / 1000)k" : n.formatted()
  }

  private func gateLine(level n: Int) -> String? {
    guard !app.progress.isOpen(n + 1), let w = Worlds.world(ofLevel: n + 1), let r = Worlds.realm(w.realm) else { return nil }
    return "\(r.name) opens at \(Gates.stars(toOpen: r.number)) stars. Win \(app.progress.starsShort(r.number)) more."
  }

  @ViewBuilder private func winActions(level n: Int, grade: Grade) -> some View {
    if app.progress.pendingCheer != nil {
      // A world just finished: its moment plays on the way out.
      Button("Celebrate") { app.route = .map }.buttonStyle(ChunkyStyle())
    } else if app.progress.isOpen(n + 1) {
      Button("Level \(n + 1)") { session.nextLevel() }.buttonStyle(ChunkyStyle())
    } else {
      Button("Find stars to win") { app.route = .play(.campaign(app.progress.nextUp)) }.buttonStyle(ChunkyStyle())
    }
    HStack(spacing: 10) {
      if grade != .s || app.progress.challengesDone(n).contains(false) {
        Button { session.restart() } label: {
          Label(grade != .s ? "Retry for S" : "Retry", systemImage: "arrow.counterclockwise")
        }
        .buttonStyle(QuietStyle())
        .accessibilityIdentifier("retry")
      }
      Button("Journey") { app.route = .map }.buttonStyle(QuietStyle())
    }
  }

  // MARK: Campaign: a loss

  @ViewBuilder private func loseCard(_ g: Game, level n: Int) -> some View {
    let cause = session.run.lossCause ?? .big
    AuroraSpot(arena: session.arena) {
      VStack(spacing: 8) {
        HStack(spacing: 8) {
          Text("LEVEL \(n) · OVERLOADED").font(.game(.caption, .heavy)).tracking(2).foregroundStyle(.white.opacity(0.9))
          if g.difficulty == .overdrive { OverdriveTag(big: true) }
        }
        HStack(spacing: 6) {
          ForEach(0..<g.tuning.shields, id: \.self) { _ in ArtImage(item: .glyph(.shieldOff), size: 30) }
        }
        .accessibilityHidden(true)
        Text(cause.headline).font(.game(.title, .black)).foregroundStyle(.white)
          .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
          .accessibilityIdentifier("lossReason")
        Text(cause.hint).font(.game(.subheadline, .bold)).foregroundStyle(.white)
          .padding(.horizontal, 12).padding(.vertical, 5)
          .background(Capsule().fill(.black.opacity(0.45)))
      }
      .padding(16)
      .frame(maxWidth: .infinity)
    }
    Button { session.restart() } label: { Label("Retry", systemImage: "arrow.counterclockwise") }
      .buttonStyle(ChunkyStyle())
      .accessibilityIdentifier("retry")
    VStack(spacing: 5) {
      ForEach(Array(session.challenges.enumerated()), id: \.offset) { i, c in
        ChallengeRow(challenge: c, state: app.progress.challengesDone(n).indices.contains(i) && app.progress.challengesDone(n)[i] ? .had : .missed, compact: true)
      }
    }
    Button("Journey") { app.route = .map }.buttonStyle(QuietStyle())
  }

  // MARK: Arcade, daily and two players

  @ViewBuilder private func otherCard(_ g: Game) -> some View {
    AuroraSpot(arena: session.arena) {
      VStack(spacing: 8) {
        Text(heading(g)).font(.game(.title, .black)).foregroundStyle(.white).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        Text(shown.formatted())
          .font(.system(size: 50, weight: .black, design: .rounded))
          .monospacedDigit()
          .foregroundStyle(LinearGradient(colors: [.white, Theme.sun], startPoint: .top, endPoint: .bottom))
          .contentTransition(.numericText(value: Double(shown)))
          .minimumScaleFactor(0.6).lineLimit(1)
        if session.resultWasBest {
          Text("New best!").font(.game(.footnote, .heavy)).foregroundStyle(.white)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(Capsule().fill(.black.opacity(0.42)))
        }
      }
      .padding(16)
      .frame(maxWidth: .infinity)
    }
    Text(sub(g)).font(.game(.subheadline, .semibold)).foregroundStyle(Theme.muted).frame(maxWidth: .infinity).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
    switch session.mode {
    case .versus:
      Button("Rematch") { session.restart() }.buttonStyle(ChunkyStyle())
      Button("Menu") { app.route = .home }.buttonStyle(QuietStyle())
    case .arcade:
      if let wave = session.arcadeNewCheckpoint {
        Text("Checkpoint unlocked: wave \(wave), \(Arcade.stage(wave).name)").font(.game(.footnote, .heavy)).foregroundStyle(Theme.sun)
          .multilineTextAlignment(.center).accessibilityIdentifier("arcade-checkpoint")
      }
      let from = app.progress.arcade.checkpoint
      if from > 1 {
        Button("Continue from wave \(from)") { app.arcadeFrom = from; session.restart() }.buttonStyle(ChunkyStyle())
          .accessibilityIdentifier("arcade-continue")
        Button("Start from wave 1") { app.arcadeFrom = 1; session.restart() }.buttonStyle(QuietStyle())
      } else {
        Button("Play again") { session.restart() }.buttonStyle(ChunkyStyle())
      }
      Button("Arcade") { app.route = .arcade }.buttonStyle(QuietStyle())
    default:
      Button("Play again") { session.restart() }.buttonStyle(ChunkyStyle())
      Button("Menu") { app.route = .home }.buttonStyle(QuietStyle())
    }
  }

  private func heading(_ g: Game) -> String {
    switch session.mode {
    case .versus: g.winner.map { "\(Seat.name($0)) wins" } ?? "Draw"
    case .arcade: "Run over"
    default: g.status == .won ? "Daily cleared" : "Overloaded"
    }
  }
  private func sub(_ g: Game) -> String {
    switch session.mode {
    case .versus: g.players.contains { $0.shields <= 0 } ? "Last shield gone." : "All clear. Top score wins."
    case .arcade: g.startWave > 1 ? "From wave \(g.startWave) to wave \(g.waves)." : "You lasted \(g.waves) \(g.waves == 1 ? "wave" : "waves")."
    default: g.status == .won ? "New level tomorrow." : "Out of shields. You can try again today."
    }
  }

  // MARK: The show

  /// Score counts up, stars land, the grade slams down, then the challenges tick in one by one.
  private func play(_ g: Game) async {
    let player = g.versus ? (g.winner.map { g.players[$0] } ?? g.players[0]) : g.players[0]
    // A level shows its own points, the same ones its grade is judged on.
    let target = session.isCampaign ? session.run.score : player.score
    let count = session.challenges.count
    if reduceMotion {
      shown = target; starsIn = g.stars; stamped = true; ticked = count; settled = true
      #if DEBUG
      Debug.ready("result-settled")
      #endif
      return
    }
    guard session.isCampaign, won else {
      await countUp(to: target, steps: session.isCampaign ? 10 : 24)
      settled = true
      #if DEBUG
      Debug.ready("result-settled")
      #endif
      return
    }
    await countUp(to: target, steps: 20)
    for s in 0..<g.stars {
      try? await Task.sleep(for: .milliseconds(200))
      starsIn = s + 1
      Sound.shared.blip(660 + Double(s) * 220, 0.12)
    }
    try? await Task.sleep(for: .milliseconds(240))
    withAnimation(.spring(duration: 0.32, bounce: 0.5)) { stamped = true }
    Haptics.shared.hit()
    Sound.shared.blip(session.grade == .s ? 1320 : 880, 0.16)
    try? await Task.sleep(for: .milliseconds(380))
    for i in 0..<count {
      ticked = i + 1
      if state(i) == .new { Haptics.shared.tap(); Sound.shared.blip(990 + Double(i) * 160, 0.1) }
      try? await Task.sleep(for: .milliseconds(320))
    }
    withAnimation(.easeOut(duration: 0.25)) { settled = true }
    #if DEBUG
    Debug.ready("result-settled")
    #endif
  }

  private func countUp(to target: Int, steps: Int) async {
    for i in 1...steps {
      try? await Task.sleep(for: .milliseconds(28))
      let k = Double(i) / Double(steps)
      withAnimation(.linear(duration: 0.03)) { shown = Int(Double(target) * (1 - pow(1 - k, 3))) }
    }
    shown = target
  }
}
