// Health, observed (native only): MetricKit's daily metrics and diagnostics, memory warnings, the save's recoveries,
// and signposts for Instruments. No SDK: Apple's MetricKit, reduced on the device to numbers and enums
// (`HingePopCore/Telemetry.swift`, checked by `Insights.clean`), then queued and sent by `Usage` like every other
// event: the same Share usage stats switch, the same batches, never during play. Call stack trees, file paths,
// termination reasons, exception names and every other string a payload carries stay on the device.
//
// Debug: `-diagnostics` feeds the path a fake metric payload and one of each diagnostic (with `-insights-dry` they're
// printed). Xcode's Debug > Simulate MetricKit Payloads exercises the real subscriber on a device.
import Foundation
import MetricKit
import os
import UIKit
import HingePopCore

/// os_signpost points of interest: they show in Instruments' Points of Interest track (level load, the level itself,
/// the save's load, MetricKit deliveries, memory warnings). Cheap when nothing is recording.
enum Signposts {
  static let log = OSLog(subsystem: "com.mutaafaziz.hingepop", category: .pointsOfInterest)
  static let signposter = OSSignposter(logHandle: log)

  static func interval<T>(_ name: StaticString, _ body: () throws -> T) rethrows -> T {
    try signposter.withIntervalSignpost(name) { try body() }
  }
  static func begin(_ name: StaticString) -> OSSignpostIntervalState {
    signposter.beginInterval(name, id: signposter.makeSignpostID())
  }
  static func end(_ name: StaticString, _ state: OSSignpostIntervalState) { signposter.endInterval(name, state) }
  static func event(_ name: StaticString, _ detail: String = "") { signposter.emitEvent(name, "\(detail, privacy: .public)") }
}

/// Things that can be dropped and rebuilt when memory runs short. Owners register a closure (a cache's purge); a
/// memory warning runs them all on the main thread. Nothing here may be needed mid-frame.
@MainActor
enum MemoryRelief {
  private static var handlers: [(name: String, run: () -> Void)] = []
  static func register(_ name: String, _ run: @escaping () -> Void) {
    handlers.removeAll { $0.name == name }
    handlers.append((name, run))
  }
  static func relieve() { for h in handlers { h.run() } }
}

/// Its state is main-actor only; MetricKit calls the two `didReceive`s on its own queue, and they touch no state.
final class Diagnostics: NSObject, MXMetricManagerSubscriber, @unchecked Sendable {
  @MainActor static let shared = Diagnostics()
  private static let logger = Logger(subsystem: "com.mutaafaziz.hingepop", category: "health")
  /// At most this many diagnostics from one delivery (a crash loop shouldn't flood the queue).
  static let diagnosticsCap = 20

  @MainActor private var started = false
  @MainActor private var observer: NSObjectProtocol?
  /// Memory warnings this launch.
  @MainActor private(set) var memoryWarnings = 0

  /// Once, at launch (AppModel). `saveSource` is how the save loaded (`SaveVault.Source`).
  @MainActor func start(saveSource: String, saveFromTheFuture: Bool = false) {
    guard !started else { return }
    started = true
    if Telemetry.SAVE_SOURCES.contains(saveSource) {
      Self.logger.notice("save recovered: \(saveSource, privacy: .public)")
      Usage.shared.track("save_recovered", ["source": .text(saveSource), "future": .bool(saveFromTheFuture)])
    }
    MXMetricManager.shared.add(self)
    observer = NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification,
                                                      object: nil, queue: .main) { [weak self] _ in
      MainActor.assumeIsolated { self?.memoryWarning() }
    }
    #if DEBUG
    if Debug.has("-diagnostics") { injectFakePayloads() }
    #endif
  }

  @MainActor private func memoryWarning() {
    memoryWarnings += 1
    Signposts.event("memory_warning", "\(memoryWarnings)")
    Self.logger.notice("memory warning \(self.memoryWarnings)")
    FrameMeter.shared.memoryWarning()
    MemoryRelief.relieve()
  }

  // MARK: MetricKit (its callbacks arrive on a background queue)

  func didReceive(_ payloads: [MXMetricPayload]) {
    let events = payloads.map { ("app_metrics", Self.metrics($0)) }
    Self.deliver(events)
  }

  func didReceive(_ payloads: [MXDiagnosticPayload]) {
    let events = payloads.flatMap(Self.diagnostics).prefix(Self.diagnosticsCap).map { ("app_diagnostic", $0) }
    Self.deliver(Array(events))
  }

  /// To the main actor and into the queue (held if a level is in play), then a flush if it's a quiet moment.
  private static func deliver(_ events: [(String, [String: Insights.Value])]) {
    guard !events.isEmpty else { return }
    Task { @MainActor in
      Signposts.event("metric_payload", "\(events.count)")
      for (name, props) in events { Usage.shared.track(name, props) }
      Usage.shared.flush()
    }
  }

  // MARK: Payloads → numbers

  static func ms(_ m: Measurement<UnitDuration>?) -> Double? { m.map { Telemetry.round($0.converted(to: .milliseconds).value) } }
  static func mb(_ m: Measurement<UnitInformationStorage>?) -> Double? { m.map { Telemetry.round($0.converted(to: .megabytes).value, 1) } }

  static func buckets(_ h: MXHistogram<UnitDuration>?) -> [Telemetry.Bucket] {
    guard let h else { return [] }
    var out: [Telemetry.Bucket] = []
    let e = h.bucketEnumerator
    while let b = e.nextObject() as? MXHistogramBucket<UnitDuration> {
      out.append(.init(startMs: b.bucketStart.converted(to: .milliseconds).value,
                       endMs: b.bucketEnd.converted(to: .milliseconds).value, count: b.bucketCount))
    }
    return out
  }

  static func metrics(_ p: MXMetricPayload) -> [String: Insights.Value] {
    let launch = Telemetry.summarize(buckets(p.applicationLaunchMetrics?.histogrammedTimeToFirstDraw), bands: Telemetry.launchBands)
    let resume = Telemetry.summarize(buckets(p.applicationLaunchMetrics?.histogrammedApplicationResumeTime))
    let hangs = Telemetry.summarize(buckets(p.applicationResponsivenessMetrics?.histogrammedApplicationHangTime))
    var exits: Exits?
    if let x = p.applicationExitMetrics {
      let f = x.foregroundExitData, b = x.backgroundExitData
      exits = Exits(normal: f.cumulativeNormalAppExitCount,
                    crash: f.cumulativeBadAccessExitCount + f.cumulativeIllegalInstructionExitCount + f.cumulativeAbnormalExitCount,
                    watchdog: f.cumulativeAppWatchdogExitCount, memory: f.cumulativeMemoryResourceLimitExitCount,
                    bgMemory: b.cumulativeMemoryPressureExitCount + b.cumulativeMemoryResourceLimitExitCount,
                    bgCPU: b.cumulativeCPUResourceLimitExitCount,
                    bgOther: b.cumulativeBadAccessExitCount + b.cumulativeIllegalInstructionExitCount + b.cumulativeAbnormalExitCount
                      + b.cumulativeAppWatchdogExitCount + b.cumulativeSuspendedWithLockedFileExitCount
                      + b.cumulativeBackgroundTaskAssertionTimeoutExitCount)
    }
    return metricProps(version: p.latestApplicationVersion, os: p.metaData?.osVersion,
                       hours: p.timeStampEnd.timeIntervalSince(p.timeStampBegin) / 3600,
                       launch: launch, resume: resume, hangs: hangs,
                       peakMB: mb(p.memoryMetrics?.peakMemoryUsage),
                       cpuS: p.cpuMetrics.map { $0.cumulativeCPUTime.converted(to: .seconds).value },
                       gpuS: p.gpuMetrics.map { $0.cumulativeGPUTime.converted(to: .seconds).value },
                       fgMin: p.applicationTimeMetrics.map { $0.cumulativeForegroundTime.converted(to: .minutes).value },
                       bgMin: p.applicationTimeMetrics.map { $0.cumulativeBackgroundTime.converted(to: .minutes).value },
                       writesMB: mb(p.diskIOMetrics?.cumulativeLogicalWrites), exits: exits)
  }

  struct Exits { var normal = 0, crash = 0, watchdog = 0, memory = 0, bgMemory = 0, bgCPU = 0, bgOther = 0 }

  /// The metric event's props from plain values (the fake payload uses this too).
  static func metricProps(version: String, os: String?, hours: Double, launch: Telemetry.Summary, resume: Telemetry.Summary,
                          hangs: Telemetry.Summary, peakMB: Double?, cpuS: Double?, gpuS: Double?, fgMin: Double?, bgMin: Double?,
                          writesMB: Double?, exits: Exits?) -> [String: Insights.Value] {
    var p: [String: Insights.Value] = ["app_version": .text(version), "period_h": .num(Telemetry.round(hours, 1))]
    if let os, let m = Telemetry.osMajor(os) { p["os_major"] = .num(m) }
    if launch.count > 0 {
      p["launches"] = .num(Double(launch.count))
      p["launch_p50_ms"] = .num(Telemetry.round(launch.p50Ms)); p["launch_p90_ms"] = .num(Telemetry.round(launch.p90Ms))
      for (key, n) in zip(["launch_under_1s", "launch_1_2s", "launch_2_4s", "launch_over_4s"], launch.banded) { p[key] = .num(Double(n)) }
    }
    if resume.count > 0 { p["resumes"] = .num(Double(resume.count)); p["resume_p50_ms"] = .num(Telemetry.round(resume.p50Ms)) }
    p["hangs"] = .num(Double(hangs.count))
    if hangs.count > 0 { p["hang_p50_ms"] = .num(Telemetry.round(hangs.p50Ms)); p["hang_max_ms"] = .num(Telemetry.round(hangs.maxMs)) }
    if let peakMB { p["peak_mem_mb"] = .num(peakMB) }
    if let cpuS { p["cpu_s"] = .num(Telemetry.round(cpuS, 1)) }
    if let gpuS { p["gpu_s"] = .num(Telemetry.round(gpuS, 1)) }
    if let fgMin { p["fg_min"] = .num(Telemetry.round(fgMin, 1)) }
    if let bgMin { p["bg_min"] = .num(Telemetry.round(bgMin, 1)) }
    if let writesMB { p["writes_mb"] = .num(writesMB) }
    if let x = exits {
      p["exit_normal"] = .num(Double(x.normal)); p["exit_crash"] = .num(Double(x.crash)); p["exit_watchdog"] = .num(Double(x.watchdog))
      p["exit_memory"] = .num(Double(x.memory)); p["exit_bg_memory"] = .num(Double(x.bgMemory)); p["exit_bg_cpu"] = .num(Double(x.bgCPU))
      p["exit_bg_other"] = .num(Double(x.bgOther))
    }
    return p
  }

  /// One event per diagnostic: its kind and numbers. Never `callStackTree`, `terminationReason`,
  /// `virtualMemoryRegionInfo`, `exceptionReason` or anything else that's text.
  static func diagnostics(_ p: MXDiagnosticPayload) -> [[String: Insights.Value]] {
    func base(_ kind: String, _ d: MXDiagnostic) -> [String: Insights.Value] {
      var e: [String: Insights.Value] = ["kind": .text(kind), "app_version": .text(d.applicationVersion)]
      if let m = Telemetry.osMajor(d.metaData.osVersion) { e["os_major"] = .num(m) }
      return e
    }
    var out: [[String: Insights.Value]] = []
    for c in p.crashDiagnostics ?? [] {
      var e = base("crash", c)
      if let t = c.exceptionType { e["exception_type"] = .num(t.doubleValue) }
      if let k = c.exceptionCode { e["exception_code"] = .num(k.doubleValue) }
      if let s = c.signal { e["signal"] = .num(s.doubleValue) }
      out.append(e)
    }
    for h in p.hangDiagnostics ?? [] {
      var e = base("hang", h)
      if let v = ms(h.hangDuration) { e["hang_ms"] = .num(v) }
      out.append(e)
    }
    for c in p.cpuExceptionDiagnostics ?? [] {
      var e = base("cpu_exception", c)
      e["cpu_s"] = .num(Telemetry.round(c.totalCPUTime.converted(to: .seconds).value, 1))
      e["sampled_s"] = .num(Telemetry.round(c.totalSampledTime.converted(to: .seconds).value, 1))
      out.append(e)
    }
    for d in p.diskWriteExceptionDiagnostics ?? [] {
      var e = base("disk_write_exception", d)
      if let v = mb(d.totalWritesCaused) { e["writes_mb"] = .num(v) }
      out.append(e)
    }
    if #available(iOS 16.0, *) {
      for l in p.appLaunchDiagnostics ?? [] {
        var e = base("launch", l)
        if let v = ms(l.launchDuration) { e["launch_ms"] = .num(v) }
        out.append(e)
      }
    }
    return out
  }

  #if DEBUG
  /// -diagnostics: MetricKit's payload classes can't be made by hand, so this feeds the same path from the point
  /// where a payload has become numbers: a day's metrics and one of each diagnostic.
  @MainActor private func injectFakePayloads() {
    let v = Usage.release.isEmpty ? "0.0.0" : Usage.release
    let launch = Telemetry.summarize([.init(startMs: 0, endMs: 1000, count: 6), .init(startMs: 1000, endMs: 2000, count: 3),
                                      .init(startMs: 4000, endMs: 5000, count: 1)], bands: Telemetry.launchBands)
    let hangs = Telemetry.summarize([.init(startMs: 250, endMs: 500, count: 2), .init(startMs: 1000, endMs: 2000, count: 1)])
    let metrics = Self.metricProps(version: v, os: "iPhone OS 26.1 (23B5)", hours: 24, launch: launch,
                                   resume: Telemetry.summarize([.init(startMs: 0, endMs: 200, count: 12)]), hangs: hangs,
                                   peakMB: 412.5, cpuS: 312.4, gpuS: 120.2, fgMin: 48, bgMin: 2.5, writesMB: 3.2,
                                   exits: Exits(normal: 9, crash: 1, watchdog: 0, memory: 1, bgMemory: 2, bgCPU: 0, bgOther: 0))
    let os: [String: Insights.Value] = ["app_version": .text(v), "os_major": .num(26)]
    let diagnostics: [[String: Insights.Value]] = [
      os.merging(["kind": .text("crash"), "exception_type": .num(1), "exception_code": .num(1), "signal": .num(11)]) { a, _ in a },
      os.merging(["kind": .text("hang"), "hang_ms": .num(2750)]) { a, _ in a },
      os.merging(["kind": .text("cpu_exception"), "cpu_s": .num(90), "sampled_s": .num(180)]) { a, _ in a },
      os.merging(["kind": .text("disk_write_exception"), "writes_mb": .num(1024)]) { a, _ in a },
      os.merging(["kind": .text("launch"), "launch_ms": .num(4200)]) { a, _ in a },
    ]
    Self.deliver([("app_metrics", metrics)] + diagnostics.map { ("app_diagnostic", $0) })
  }
  #endif
}
