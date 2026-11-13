import SwiftUI
import HingePopCore

/// Arcade's home: the best run, a big way back in from the furthest checkpoint, and the ladder of stages.
struct ArcadeView: View {
  @Environment(AppModel.self) private var app
  var body: some View {
    let log = app.progress.arcade
    let from = log.checkpoint
    ZStack {
      ArenaBackground(arena: .circuit)
      VStack(spacing: 0) {
        BackBar(title: "Arcade")
        ScrollView {
          VStack(spacing: 16) {
            scoreboard(log)
            VStack(spacing: 10) {
              if from > 1 {
                Button { app.playArcade(from: from) } label: {
                  HStack(spacing: 8) {
                    Image(systemName: "play.fill").accessibilityHidden(true)
                    Text("Continue from wave \(from)")
                  }
                }
                .buttonStyle(ChunkyStyle(colors: [Theme.cyan, Color(red: 0.36, green: 0.4, blue: 1)]))
                .accessibilityIdentifier("arcade-continue")
                Text(Arcade.stage(from).name + " · " + Arcade.stage(from).nod).font(.game(.footnote, .semibold)).foregroundStyle(Theme.muted)
                Button("Start from wave 1") { app.playArcade() }.buttonStyle(QuietStyle()).accessibilityIdentifier("arcade-start")
              } else {
                Button { app.playArcade() } label: {
                  HStack(spacing: 8) {
                    Image(systemName: "play.fill").accessibilityHidden(true)
                    Text(log.runs == 0 ? "Insert coin" : "Play again")
                  }
                }
                .buttonStyle(ChunkyStyle(colors: [Theme.cyan, Color(red: 0.36, green: 0.4, blue: 1)]))
                .accessibilityIdentifier("arcade-start")
                Text("Reach wave \(Arcade.every) to save a checkpoint.").font(.game(.footnote, .semibold)).foregroundStyle(Theme.muted)
              }
            }
            ladder(log)
          }
          .padding(.horizontal, 20)
          .padding(.bottom, 24)
          .frame(maxWidth: 520)
          .frame(maxWidth: .infinity)
        }
      }
    }
    #if DEBUG
    .task { Debug.ready("arcade") }
    #endif
  }

  private func scoreboard(_ log: ArcadeLog) -> some View {
    VStack(spacing: 6) {
      Text("HIGH SCORE").font(.game(.caption, .heavy)).tracking(3).foregroundStyle(Theme.cyan)
      Text(app.progress.arcadeBest.formatted())
        .font(.system(size: 54, weight: .black, design: .rounded)).monospacedDigit()
        .foregroundStyle(LinearGradient(colors: [.white, Theme.cyan], startPoint: .top, endPoint: .bottom))
        .minimumScaleFactor(0.5).lineLimit(1)
      HStack(spacing: 8) {
        Chip(icon: "flag.checkered", text: "Best wave \(log.bestWave)", color: Theme.sun)
        Chip(icon: "arrow.triangle.2.circlepath", text: "\(log.runs) \(log.runs == 1 ? "run" : "runs")", color: Theme.violet)
      }
      if log.runs > 0 {
        Text("Last run: wave \(log.lastWave), \(log.lastScore.formatted()) points").font(.game(.footnote, .semibold)).foregroundStyle(Theme.muted)
      }
    }
    .padding(18)
    .frame(maxWidth: .infinity)
    .background(RoundedRectangle(cornerRadius: 24).fill(Theme.panel.opacity(0.88)))
    .overlay(RoundedRectangle(cornerRadius: 24).stroke(Theme.cyan.opacity(0.6), lineWidth: 1.5))
    .accessibilityElement(children: .combine)
  }

  private func ladder(_ log: ArcadeLog) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("CHECKPOINTS").font(.game(.caption, .heavy)).tracking(3).foregroundStyle(Theme.muted).padding(.leading, 4)
      ForEach(Arcade.ladder(best: log.bestWave).reversed(), id: \.wave) { stage in
        let open = stage.wave <= log.checkpoint
        let current = stage.wave == log.checkpoint
        Button { app.playArcade(from: stage.wave) } label: {
          HStack(spacing: 12) {
            Text("\(stage.wave)").font(.system(size: 20, weight: .black, design: .rounded)).monospacedDigit()
              .foregroundStyle(open ? Theme.night : Theme.muted)
              .frame(width: 46, height: 46)
              .background(Circle().fill(open ? AnyShapeStyle(LinearGradient(colors: [Theme.sun, Theme.orange], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(Theme.panel)))
              .overlay(Circle().stroke(open ? Theme.sun : Theme.panelEdge, lineWidth: 1.5))
            VStack(alignment: .leading, spacing: 2) {
              Text(stage.name).font(.game(.headline, .heavy)).foregroundStyle(open ? Theme.ink : Theme.muted)
              Text(open ? stage.nod : "Reach wave \(stage.wave) to unlock").font(.game(.caption, .semibold)).foregroundStyle(Theme.muted)
            }
            Spacer()
            Image(systemName: open ? (current ? "play.circle.fill" : "play.circle") : "lock.fill")
              .font(.title2).foregroundStyle(open ? Theme.cyan : Theme.panelEdge).accessibilityHidden(true)
          }
          .padding(10)
          .background(RoundedRectangle(cornerRadius: 18).fill(Theme.panel.opacity(current ? 0.95 : 0.7)))
          .overlay(RoundedRectangle(cornerRadius: 18).stroke(current ? Theme.cyan : Theme.panelEdge.opacity(0.5), lineWidth: current ? 2 : 1))
        }
        .buttonStyle(.plain)
        .disabled(!open)
        .accessibilityLabel(open ? "Start from wave \(stage.wave), \(stage.name)" : "Wave \(stage.wave), \(stage.name), locked")
      }
    }
  }
}
