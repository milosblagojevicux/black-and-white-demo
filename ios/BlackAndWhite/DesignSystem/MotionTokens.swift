import SwiftUI
import CoreText
import UIKit

struct FakeoutMotionPreset: Equatable, Sendable {
    let misdirectionAmount: Double
    let commitmentMilliseconds: Int
    let holdMilliseconds: Int
    let reversalMilliseconds: Int
    let preSlamPauseMilliseconds: Int

    static let production = FakeoutMotionPreset(
        misdirectionAmount: 0.8,
        commitmentMilliseconds: 600,
        holdMilliseconds: 0,
        reversalMilliseconds: 200,
        preSlamPauseMilliseconds: 0
    )

    static let experimentalLabInitial = FakeoutMotionPreset(
        misdirectionAmount: 0.8,
        commitmentMilliseconds: 280,
        holdMilliseconds: 220,
        reversalMilliseconds: 140,
        preSlamPauseMilliseconds: 40
    )

    var swiftInitializer: String {
        let amount = String(
            format: "%g",
            locale: Locale(identifier: "en_US_POSIX"),
            misdirectionAmount
        )
        return """
        FakeoutMotionPreset(
            misdirectionAmount: \(amount),
            commitmentMilliseconds: \(commitmentMilliseconds),
            holdMilliseconds: \(holdMilliseconds),
            reversalMilliseconds: \(reversalMilliseconds),
            preSlamPauseMilliseconds: \(preSlamPauseMilliseconds)
        )
        """
    }
}

enum FakeoutMotionPlaybackSpeed: Double, CaseIterable, Identifiable, Sendable {
    case quarter = 0.25
    case half = 0.5
    case full = 1

    var id: Double { rawValue }
    var label: String { "\(rawValue.formatted(.number.precision(.fractionLength(0...2))))×" }
}

enum FakeoutMotionPhase: String, CaseIterable, Equatable, Sendable {
    case preflightDownRight
    case preflightUpLeft
    case preflightSettle
    case commitment
    case hold
    case reversal
    case preSlamPause
    case slam
}

struct FakeoutMotionStep: Equatable, Sendable {
    let phase: FakeoutMotionPhase
    let durationMilliseconds: Int
    let targetVerdict: Verdict
    let tensionPull: Double
    let resolutionProgress: Double
}

struct FakeoutMotionPlan: Equatable, Sendable {
    let steps: [FakeoutMotionStep]

    init(
        preset: FakeoutMotionPreset,
        finalVerdict: Verdict,
        playbackSpeed: Double = 1
    ) {
        let safeSpeed = max(playbackSpeed, 0.01)
        let scaled: (Int) -> Int = { milliseconds in
            Int((Double(milliseconds) / safeSpeed).rounded())
        }
        let wrongVerdict = finalVerdict == .black ? Verdict.white : Verdict.black
        let pullToward: (Verdict) -> Double = { verdict in
            verdict == .black
                ? BWMotion.decidingDownRightPull
                : BWMotion.decidingUpLeftSettledPull
        }
        let normalPullCycle = [
            FakeoutMotionStep(phase: .preflightDownRight, durationMilliseconds: scaled(BWMotion.decidingFirstPullMilliseconds), targetVerdict: .black, tensionPull: BWMotion.decidingDownRightPull, resolutionProgress: 0),
            FakeoutMotionStep(phase: .preflightUpLeft, durationMilliseconds: scaled(BWMotion.decidingSecondPullMilliseconds), targetVerdict: .white, tensionPull: BWMotion.decidingUpLeftOvershootPull, resolutionProgress: 0),
            FakeoutMotionStep(phase: .preflightSettle, durationMilliseconds: scaled(BWMotion.decidingSettlePullMilliseconds), targetVerdict: .white, tensionPull: BWMotion.decidingUpLeftSettledPull, resolutionProgress: 0)
        ]

        steps = Array(repeating: normalPullCycle, count: BWMotion.fakeoutPreflightCycleCount)
            .flatMap { $0 } + [
            FakeoutMotionStep(
                phase: .commitment,
                durationMilliseconds: scaled(preset.commitmentMilliseconds),
                targetVerdict: wrongVerdict,
                tensionPull: pullToward(wrongVerdict),
                resolutionProgress: -preset.misdirectionAmount
            ),
            FakeoutMotionStep(
                phase: .hold,
                durationMilliseconds: scaled(preset.holdMilliseconds),
                targetVerdict: wrongVerdict,
                tensionPull: pullToward(wrongVerdict),
                resolutionProgress: -preset.misdirectionAmount
            ),
            FakeoutMotionStep(
                phase: .reversal,
                durationMilliseconds: scaled(preset.reversalMilliseconds),
                targetVerdict: finalVerdict,
                tensionPull: pullToward(finalVerdict),
                resolutionProgress: 1
            ),
            FakeoutMotionStep(
                phase: .preSlamPause,
                durationMilliseconds: scaled(preset.preSlamPauseMilliseconds),
                targetVerdict: finalVerdict,
                tensionPull: pullToward(finalVerdict),
                resolutionProgress: 1
            ),
            FakeoutMotionStep(
                phase: .slam,
                durationMilliseconds: scaled(BWMotion.verdictSlamTotalMilliseconds),
                targetVerdict: finalVerdict,
                tensionPull: pullToward(finalVerdict),
                resolutionProgress: 1
            )
        ]
    }
}

struct FakeoutMotionLabSettings: Equatable, Sendable {
    var preset = FakeoutMotionPreset.experimentalLabInitial
    var playbackSpeed = FakeoutMotionPlaybackSpeed.full

    mutating func resetToProductionDefaults() {
        preset = .production
        playbackSpeed = .full
    }
}

enum FakeoutMotionLabAvailability {
    static var isAvailable: Bool {
#if DEBUG
        true
#else
        false
#endif
    }

    static func shouldPresent(arguments: [String]) -> Bool {
        isAvailable && arguments.contains("--motion-lab-fakeout")
    }
}

struct LoadingMotionBlobPreset: Equatable, Sendable {
    let deformationAmplitude: Double
    let speed: Double
    let phase: Double
    let slowRotation: Double
}

struct LoadingMotionPreset: Equatable, Sendable {
    let size: Double
    let centerRatio: Double
    let outlineWidth: Double
    let firstBlob: LoadingMotionBlobPreset
    let secondBlob: LoadingMotionBlobPreset
    let thirdBlob: LoadingMotionBlobPreset
    let centerBlob: LoadingMotionBlobPreset
    let glowRadius: Double
    let glowOpacity: Double

    // Owner-approved native production preset from the Loading Motion Lab.
    static let production = LoadingMotionPreset(
        size: 34,
        centerRatio: 0.68,
        outlineWidth: 0.9,
        firstBlob: LoadingMotionBlobPreset(
            deformationAmplitude: 0.13,
            speed: 0.55,
            phase: 0,
            slowRotation: 0.035
        ),
        secondBlob: LoadingMotionBlobPreset(
            deformationAmplitude: 0.09,
            speed: 0.4,
            phase: 0.33,
            slowRotation: -0.025
        ),
        thirdBlob: LoadingMotionBlobPreset(
            deformationAmplitude: 0.16,
            speed: 0.4,
            phase: 0.67,
            slowRotation: 0.018
        ),
        centerBlob: LoadingMotionBlobPreset(
            deformationAmplitude: 0.09,
            speed: 0.2,
            phase: 0.21,
            slowRotation: 0.04
        ),
        glowRadius: 0,
        glowOpacity: 0
    )

    static let experimentalLabInitial = LoadingMotionPreset(
        size: 34,
        centerRatio: 0.61,
        outlineWidth: 0.9,
        firstBlob: LoadingMotionBlobPreset(
            deformationAmplitude: 0.13,
            speed: 0.55,
            phase: 0,
            slowRotation: 0.035
        ),
        secondBlob: LoadingMotionBlobPreset(
            deformationAmplitude: 0.09,
            speed: 0.4,
            phase: 0.33,
            slowRotation: -0.025
        ),
        thirdBlob: LoadingMotionBlobPreset(
            deformationAmplitude: 0.16,
            speed: 0.72,
            phase: 0.67,
            slowRotation: 0.018
        ),
        centerBlob: LoadingMotionBlobPreset(
            deformationAmplitude: 0.1,
            speed: 0.32,
            phase: 0.48,
            slowRotation: -0.02
        ),
        glowRadius: 3,
        glowOpacity: 0.3
    )

    var blobs: [LoadingMotionBlobPreset] {
        [firstBlob, secondBlob, thirdBlob]
    }

    var swiftInitializer: String {
        func number(_ value: Double) -> String {
            String(format: "%g", locale: Locale(identifier: "en_US_POSIX"), value)
        }
        func blob(_ name: String, _ value: LoadingMotionBlobPreset) -> String {
            """
            \(name): LoadingMotionBlobPreset(
                deformationAmplitude: \(number(value.deformationAmplitude)),
                speed: \(number(value.speed)),
                phase: \(number(value.phase)),
                slowRotation: \(number(value.slowRotation))
            )
            """
        }

        return """
        LoadingMotionPreset(
            size: \(number(size)),
            centerRatio: \(number(centerRatio)),
            outlineWidth: \(number(outlineWidth)),
            \(blob("firstBlob", firstBlob)),
            \(blob("secondBlob", secondBlob)),
            \(blob("thirdBlob", thirdBlob)),
            \(blob("centerBlob", centerBlob)),
            glowRadius: \(number(glowRadius)),
            glowOpacity: \(number(glowOpacity))
        )
        """
    }
}

enum LoadingMotionPlaybackSpeed: Double, CaseIterable, Identifiable, Sendable {
    case quarter = 0.25
    case half = 0.5
    case full = 1

    var id: Double { rawValue }
    var label: String { "\(rawValue.formatted(.number.precision(.fractionLength(0...2))))×" }
}

enum LoadingMotionRenderOperation: Equatable, Sendable {
    case fill(blob: Int)
    case outline(blob: Int)
    case centerCover
}

enum LoadingMotionRenderPlan {
    static let operations: [LoadingMotionRenderOperation] = [
        .fill(blob: 0),
        .fill(blob: 1),
        .fill(blob: 2),
        .outline(blob: 0),
        .outline(blob: 1),
        .outline(blob: 2),
        .centerCover
    ]
}

struct LoadingMotionLabSettings: Equatable, Sendable {
    var preset = LoadingMotionPreset.experimentalLabInitial
    var playbackSpeed = LoadingMotionPlaybackSpeed.full
    var reduceMotionPreview = false

    mutating func resetToProductionDefaults() {
        preset = .production
        playbackSpeed = .full
        reduceMotionPreview = false
    }
}

enum LoadingMotionLabAvailability {
    static var isAvailable: Bool {
#if DEBUG
        true
#else
        false
#endif
    }

    static func shouldPresent(arguments: [String]) -> Bool {
        isAvailable && arguments.contains("--motion-lab-loading")
    }
}

struct FullWidthVerdictTextMetrics: Equatable, Sendable {
    let fontSize: CGFloat
    let measuredWidth: CGFloat
    let measuredHeight: CGFloat
    let opticalWidth: CGFloat
    let horizontalOffset: CGFloat
    let fillsTargetWidth: Bool
    let constraintWarning: String?
}

enum FullWidthVerdictTextSizing {
    /// Lets rendered glyph ink, rather than its typographic side bearings, meet the verdict region edges.
    private static let opticalEdgeOverscan: CGFloat = 1

    static func metrics(
        text: String,
        targetWidth: CGFloat,
        availableHeight: CGFloat,
        weight: UIFont.Weight = .black
    ) -> FullWidthVerdictTextMetrics {
        guard !text.isEmpty, targetWidth > 0, availableHeight > 0 else {
            return FullWidthVerdictTextMetrics(fontSize: 0, measuredWidth: 0, measuredHeight: 0, opticalWidth: 0, horizontalOffset: 0, fillsTargetWidth: false, constraintWarning: "Enter text and a positive verdict region.")
        }

        let minimumReadableSize: CGFloat = 20
        let minimumMeasured = measure(text: text, fontSize: minimumReadableSize, weight: weight)
        let opticalTargetWidth = targetWidth + opticalEdgeOverscan * 2
        guard minimumMeasured.inkBounds.width <= opticalTargetWidth, minimumMeasured.size.height <= availableHeight else {
            return FullWidthVerdictTextMetrics(
                fontSize: minimumReadableSize,
                measuredWidth: minimumMeasured.size.width,
                measuredHeight: minimumMeasured.size.height,
                opticalWidth: minimumMeasured.inkBounds.width,
                horizontalOffset: horizontalOffset(
                    measuredWidth: minimumMeasured.size.width,
                    inkBounds: minimumMeasured.inkBounds,
                    targetWidth: targetWidth
                ),
                fillsTargetWidth: false,
                constraintWarning: "This label cannot fit without dropping below the minimum readable size."
            )
        }

        var low: CGFloat = minimumReadableSize
        var high: CGFloat = 600
        var best: CGFloat = 1
        for _ in 0..<28 {
            let candidate = (low + high) / 2
            let measured = measure(text: text, fontSize: candidate, weight: weight)
            if measured.inkBounds.width <= opticalTargetWidth && measured.size.height <= availableHeight {
                best = candidate
                low = candidate
            } else {
                high = candidate
            }
        }

        let measured = measure(text: text, fontSize: best, weight: weight)
        let fillsWidth = measured.inkBounds.width >= targetWidth * 0.96
        let warning = fillsWidth ? nil : (measured.size.height >= availableHeight * 0.96 ? "Height limits full width for this label." : "Label cannot fill the target width at this configuration.")
        return FullWidthVerdictTextMetrics(
            fontSize: best,
            measuredWidth: measured.size.width,
            measuredHeight: measured.size.height,
            opticalWidth: measured.inkBounds.width,
            horizontalOffset: horizontalOffset(
                measuredWidth: measured.size.width,
                inkBounds: measured.inkBounds,
                targetWidth: targetWidth
            ),
            fillsTargetWidth: fillsWidth,
            constraintWarning: warning
        )
    }

    private static func measure(text: String, fontSize: CGFloat, weight: UIFont.Weight) -> (size: CGSize, inkBounds: CGRect) {
        let font = UIFont.systemFont(ofSize: fontSize, weight: weight)
        let size = (text as NSString).size(withAttributes: [.font: font])
        let line = CTLineCreateWithAttributedString(
            NSAttributedString(string: text, attributes: [.font: font])
        )
        let inkBounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        return (size, inkBounds)
    }

    private static func horizontalOffset(measuredWidth: CGFloat, inkBounds: CGRect, targetWidth: CGFloat) -> CGFloat {
        let textOrigin = (targetWidth - measuredWidth) / 2
        let opticalOrigin = (targetWidth - inkBounds.width) / 2
        return opticalOrigin - textOrigin - inkBounds.minX
    }
}

struct FullWidthVerdictText: View {
    let text: String
    let targetWidth: CGFloat
    let availableHeight: CGFloat
    let foreground: Color
    let accessibilityLabel: String

    private var metrics: FullWidthVerdictTextMetrics {
        FullWidthVerdictTextSizing.metrics(text: text, targetWidth: targetWidth, availableHeight: availableHeight)
    }

    var body: some View {
        Text(text)
            .font(.system(size: metrics.fontSize, weight: .black, design: .default))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .frame(width: targetWidth, height: availableHeight, alignment: .center)
            .offset(x: metrics.horizontalOffset)
            .foregroundStyle(foreground)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityAddTraits(.isHeader)
    }
}

enum FullWidthVerdictLabAvailability {
    static var isAvailable: Bool {
#if DEBUG
        true
#else
        false
#endif
    }

    static func shouldPresent(arguments: [String]) -> Bool {
        isAvailable && arguments.contains("--verdict-typography-lab")
    }
}

enum BWMotion {
    static let stateTransition = Animation.easeInOut(duration: 0.28)
    static let verdictTakeover = Animation.easeIn(duration: 0.22)
    static let verdictTakeoverBeat: Duration = .milliseconds(220)
    static let decidingDownRightPull = 0.72
    static let decidingUpLeftOvershootPull = -0.9
    static let decidingUpLeftSettledPull = -0.72
    static let decidingFirstPullMilliseconds = 120
    static let decidingSecondPullMilliseconds = 180
    static let decidingSettlePullMilliseconds = 120
    static let decidingFirstPullBounce = 0.16
    static let decidingSecondPullBounce = 0.24
    static let decidingSettlePullBounce = 0.08
    static let fakeoutCommitmentBounce = decidingFirstPullBounce
    static let fakeoutReversalBounce = decidingSecondPullBounce
    static let decidingFirstPull = decidingFirstPullAnimation(playbackSpeed: 1)
    static let decidingFirstPullBeat: Duration = .milliseconds(decidingFirstPullMilliseconds)
    static let decidingSecondPull = decidingSecondPullAnimation(playbackSpeed: 1)
    static let decidingSecondPullBeat: Duration = .milliseconds(decidingSecondPullMilliseconds)
    static let decidingSettlePull = decidingSettlePullAnimation(playbackSpeed: 1)
    static let decidingSettlePullBeat: Duration = .milliseconds(decidingSettlePullMilliseconds)
    static let decidingPullCycleBeat: Duration = .milliseconds(420)
    static let fakeoutPreflightCycleCount = 2
    static let fakeoutMisdirectionBeat: Duration = .milliseconds(
        FakeoutMotionPreset.production.commitmentMilliseconds
    )
    static let fakeoutMisdirectionProgress = CGFloat(
        FakeoutMotionPreset.production.misdirectionAmount
    )
    static let fakeoutSwitchBeat: Duration = .milliseconds(
        FakeoutMotionPreset.production.reversalMilliseconds
    )
    static let verdictSlamDrop = Animation.timingCurve(0.58, 0, 0.86, 0.18, duration: 0.4)
    static let verdictSlamRebound = Animation.easeOut(duration: 0.09)
    static let verdictSlamSettle = Animation.spring(duration: 0.17, bounce: 0.12)
    static let verdictSlamShake = Animation.linear(duration: 0.22)
    static let verdictSlamRumble = Animation.linear(duration: 0.22)
    static let verdictSlamDropBeat: Duration = .milliseconds(400)
    static let verdictSlamReboundBeat: Duration = .milliseconds(90)
    static let verdictSlamSettleBeat: Duration = .milliseconds(170)
    static let verdictSlamTotalMilliseconds = 660
    static let quietReveal = Animation.easeOut(duration: 0.2)

    static func linear(milliseconds: Int) -> Animation {
        .linear(duration: Double(milliseconds) / 1_000)
    }

    static func decidingFirstPullAnimation(playbackSpeed: Double) -> Animation {
        .spring(duration: scaledSeconds(150, playbackSpeed: playbackSpeed), bounce: decidingFirstPullBounce)
    }

    static func decidingSecondPullAnimation(playbackSpeed: Double) -> Animation {
        .spring(duration: scaledSeconds(230, playbackSpeed: playbackSpeed), bounce: decidingSecondPullBounce)
    }

    static func decidingSettlePullAnimation(playbackSpeed: Double) -> Animation {
        .spring(duration: scaledSeconds(120, playbackSpeed: playbackSpeed), bounce: decidingSettlePullBounce)
    }

    static func fakeoutCommitmentAnimation(durationMilliseconds: Int) -> Animation {
        .spring(
            duration: Double(durationMilliseconds) / 1_000,
            bounce: fakeoutCommitmentBounce
        )
    }

    static func fakeoutReversalAnimation(durationMilliseconds: Int) -> Animation {
        .spring(
            duration: Double(durationMilliseconds) / 1_000,
            bounce: fakeoutReversalBounce
        )
    }

    static func verdictSlamDrop(playbackSpeed: Double) -> Animation {
        .timingCurve(0.58, 0, 0.86, 0.18, duration: scaledSeconds(400, playbackSpeed: playbackSpeed))
    }

    static func verdictSlamRebound(playbackSpeed: Double) -> Animation {
        .easeOut(duration: scaledSeconds(90, playbackSpeed: playbackSpeed))
    }

    static func verdictSlamSettle(playbackSpeed: Double) -> Animation {
        .spring(duration: scaledSeconds(170, playbackSpeed: playbackSpeed), bounce: 0.12)
    }

    static func verdictSlamShake(playbackSpeed: Double) -> Animation {
        .linear(duration: scaledSeconds(220, playbackSpeed: playbackSpeed))
    }

    static func scaledMilliseconds(_ milliseconds: Int, playbackSpeed: Double) -> Int {
        Int((Double(milliseconds) / max(playbackSpeed, 0.01)).rounded())
    }

    private static func scaledSeconds(_ milliseconds: Int, playbackSpeed: Double) -> Double {
        Double(scaledMilliseconds(milliseconds, playbackSpeed: playbackSpeed)) / 1_000
    }
}
