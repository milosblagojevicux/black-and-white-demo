import CoreHaptics
import UIKit

@MainActor
enum VerdictHaptics {
    private static let binaryGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private static let grayGenerator = UIImpactFeedbackGenerator(style: .soft)
    private static let slamEngine = VerdictSlamHapticEngine()

    static func prepare(for verdict: Verdict, theatricalSlam: Bool = false) {
        switch verdict {
        case .white, .black:
            binaryGenerator.prepare()
            if theatricalSlam {
                slamEngine.prepare()
            }
        case .gray:
            grayGenerator.prepare()
        }
    }

    static func impact(for verdict: Verdict, theatricalSlam: Bool = false) {
        switch verdict {
        case .white, .black:
            binaryGenerator.impactOccurred(intensity: theatricalSlam ? 1 : 0.9)
            if theatricalSlam {
                slamEngine.play()
            }
        case .gray:
            grayGenerator.impactOccurred(intensity: 0.45)
        }
    }
}

enum VerdictSlamHapticPattern {
    static let rumbleDuration: TimeInterval = 0.22
    static let rumbleStartIntensity: Float = 0.90
    static let rumbleMidIntensity: Float = 0.48
    static let rumbleEndIntensity: Float = 0

    static func make() throws -> CHHapticPattern {
        let rumble = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.30)
            ],
            relativeTime: 0,
            duration: rumbleDuration
        )
        let decay = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [
                CHHapticParameterCurve.ControlPoint(relativeTime: 0, value: rumbleStartIntensity),
                CHHapticParameterCurve.ControlPoint(relativeTime: 0.10, value: rumbleMidIntensity),
                CHHapticParameterCurve.ControlPoint(relativeTime: rumbleDuration, value: rumbleEndIntensity)
            ],
            relativeTime: 0
        )

        return try CHHapticPattern(events: [rumble], parameterCurves: [decay])
    }
}

@MainActor
private final class VerdictSlamHapticEngine {
    private let engine: CHHapticEngine?
    private var player: (any CHHapticPatternPlayer)?

    init() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            engine = nil
            return
        }

        engine = try? CHHapticEngine()
        engine?.isAutoShutdownEnabled = true
    }

    func prepare() {
        try? engine?.start()
    }

    func play() {
        guard let engine else { return }

        do {
            try engine.start()
            player = try engine.makePlayer(with: VerdictSlamHapticPattern.make())
            try player?.start(atTime: CHHapticTimeImmediate)
        } catch {
            return
        }
    }
}
