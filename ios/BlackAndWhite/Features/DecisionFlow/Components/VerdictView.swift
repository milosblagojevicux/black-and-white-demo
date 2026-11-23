import SwiftUI

struct VerdictView: View {
    let decision: Decision
    let reduceMotion: Bool
    let fakeoutMotionPreset: FakeoutMotionPreset
    let playbackSpeed: Double
    let askAgain: () -> Void

    @State private var verdictVisible = false
    @State private var reactionVisible = false
    @State private var actionVisible = false
    @State private var actionOpacity: CGFloat = 0
    @State private var tensionPull: CGFloat = 0
    @State private var takeoverProgress: CGFloat = 0
    @State private var verdictVerticalOffset: CGFloat = -720
    @State private var verdictImpactScale: CGFloat = 1.08
    @State private var impactShakeProgress: CGFloat = 0
    @State private var verdictRumbleProgress: CGFloat = 0
#if DEBUG
    @State private var animationTrace = "idle"
    @State private var fakeoutGeometryTrace = "idle"
#endif

    init(
        decision: Decision,
        reduceMotion: Bool,
        fakeoutMotionPreset: FakeoutMotionPreset = .production,
        playbackSpeed: Double = 1,
        askAgain: @escaping () -> Void
    ) {
        self.decision = decision
        self.reduceMotion = reduceMotion
        self.fakeoutMotionPreset = fakeoutMotionPreset
        self.playbackSpeed = playbackSpeed
        self.askAgain = askAgain
    }

    var body: some View {
        ZStack {
            verdictBackdrop

            ZStack {
                verdictHero

                if let reaction = decision.reaction, reactionVisible {
                    Text(reaction)
                        .font(BWType.reaction)
                        .multilineTextAlignment(.center)
                        .offset(y: 132)
                        .transition(.opacity)
                }
            }
            .foregroundStyle(BWColor.foreground(for: decision.verdict))
        }
        .modifier(
            VerdictSlamShakeEffect(
                progress: usesBinarySlam ? impactShakeProgress : 1
            )
        )
        .background(impactUnderlayColor.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            verdictFooter
        }
        .overlay(alignment: .topLeading) {
            if decision.motionPath == .fakeout && !reduceMotion && !verdictVisible {
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityElement()
                    .accessibilityLabel("Deciding")
                    .accessibilityIdentifier("fakeout-deciding")
            }
        }
#if DEBUG
        .overlay(alignment: .topLeading) {
            VStack {
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityElement()
                    .accessibilityLabel("Verdict animation trace")
                    .accessibilityValue(animationTrace)
                    .accessibilityIdentifier("verdict-animation-trace")

                if decision.motionPath == .fakeout {
                    Color.clear
                        .frame(width: 1, height: 1)
                        .accessibilityElement()
                        .accessibilityLabel("Fakeout geometry trace")
                        .accessibilityValue(fakeoutGeometryTrace)
                        .accessibilityIdentifier("fakeout-geometry-trace")
                }
            }
        }
#endif
        .task(id: decision.id) {
            await playEntrance()
        }
    }

    private var verdictFooter: some View {
        VStack(spacing: 0) {
            if decision.usage.state == .warning || decision.usage.state == .last {
                Text(usageMessage)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(BWColor.foreground(for: decision.verdict))
                    .accessibilityLabel("\(decision.usage.remainingToday) decisions remaining today")
                    .accessibilityIdentifier("usage-message")
                    .padding(.bottom, BWSpacing.medium)
                    .opacity(actionOpacity)
                    .accessibilityHidden(!actionVisible)
            }

            ZStack {
                Color.clear
                    .frame(height: BWLayout.bottomActionHeight)

                if actionVisible {
                    Button(action: askAgain) {
                        Text("Ask again")
                            .font(BWType.button)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .buttonStyle(
                        MonochromeActionButtonStyle(
                            shape: SplashActionSurface(),
                            fill: actionBackground,
                            foreground: actionForeground,
                            border: nil
                        )
                    )
                    .accessibilityIdentifier("ask-again")
                    .opacity(actionOpacity)
                }
            }
            .frame(height: BWLayout.bottomActionHeight)
            .padding(.horizontal, BWSpacing.medium)

            Color.clear
                .frame(height: BWSpacing.medium)
        }
    }

    @ViewBuilder
    private var verdictHero: some View {
        if decision.verdict == .gray {
            Text(decision.verdictText)
                .font(.system(size: BWType.grayVerdictSize, weight: .black, design: .default))
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, BWSpacing.large)
                .scaleEffect(verdictVisible ? 1 : 0.96, anchor: .leading)
                .opacity(verdictVisible ? 1 : 0)
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel("Verdict: \(decision.verdictText)")
                .accessibilityHidden(!verdictVisible)
                .accessibilityIdentifier("verdict-text")
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else {
            GeometryReader { geometry in
                FullWidthVerdictText(
                    text: decision.verdictText,
                    targetWidth: geometry.size.width,
                    availableHeight: min(geometry.size.height, 320),
                    foreground: BWColor.foreground(for: decision.verdict),
                    accessibilityLabel: "Verdict: \(decision.verdictText)"
                )
                .frame(
                    width: geometry.size.width,
                    height: geometry.size.height,
                    alignment: .center
                )
                .scaleEffect(verdictImpactScale)
                .offset(y: verdictVerticalOffset)
                .modifier(VerdictImpactRumbleEffect(progress: verdictRumbleProgress))
                .opacity(verdictVisible ? 1 : 0)
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel("Verdict: \(decision.verdictText)")
                .accessibilityHidden(!verdictVisible)
                .accessibilityIdentifier("verdict-text")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    @ViewBuilder
    private var verdictBackdrop: some View {
        if decision.verdict == .gray {
            BWColor.gray
                .ignoresSafeArea()
        } else {
            BWColor.white
                .ignoresSafeArea()

            DecisionTensionBackdrop(
                pull: tensionPull,
                resolution: decision.verdict,
                resolutionProgress: takeoverProgress
            )
            .fill(BWColor.black)
            .ignoresSafeArea()
        }
    }

    private var usageMessage: String {
        decision.usage.state == .last
            ? "Last one.\nMake it count."
            : "\(decision.usage.remainingToday) decisions left today.\nChoose wisely."
    }

    private var actionBackground: Color {
        decision.verdict == .gray ? BWColor.black : BWColor.foreground(for: decision.verdict)
    }

    private var actionForeground: Color {
        decision.verdict == .gray ? BWColor.white : BWColor.background(for: decision.verdict)
    }

    private var usesBinarySlam: Bool {
        decision.verdict != .gray && !reduceMotion
    }

    private var impactUnderlayColor: Color {
        usesBinarySlam
            ? BWColor.foreground(for: decision.verdict)
            : BWColor.background(for: decision.verdict)
    }

    @MainActor
    private func playEntrance() async {
        verdictVisible = false
        reactionVisible = false
        actionVisible = false
        actionOpacity = 0
        tensionPull = 0
        takeoverProgress = 0
        verdictVerticalOffset = reduceMotion || decision.verdict == .gray ? 0 : -720
        verdictImpactScale = reduceMotion || decision.verdict == .gray ? 0.98 : 1.08
        impactShakeProgress = 0
        verdictRumbleProgress = 0
#if DEBUG
        animationTrace = "idle"
        fakeoutGeometryTrace = "idle"
#endif

        if debugEntranceDelay > .zero {
            try? await Task.sleep(for: debugEntranceDelay)
        }
        guard !Task.isCancelled else { return }

        if decision.verdict != .gray {
            if reduceMotion || decision.motionPath == .instant {
                takeoverProgress = 1
#if DEBUG
                animationTrace = "instant-winning"
#endif
            } else if decision.motionPath == .fakeout {
                await playFakeoutTakeover()
                guard !Task.isCancelled else { return }
            } else {
#if DEBUG
                animationTrace = "standard-winning"
#endif
                withAnimation(BWMotion.verdictTakeover) {
                    takeoverProgress = 1
                }
                // The hero begins just before the final colour handoff, so there is
                // no perceptible blank pause after the diagonal resolves.
                try? await Task.sleep(for: .milliseconds(120))
                guard !Task.isCancelled else { return }
            }
        }

        if decision.verdict == .gray || reduceMotion {
            VerdictHaptics.prepare(for: decision.verdict)
            withAnimation(.easeOut(duration: reduceMotion ? 0.12 : 0.24)) {
                verdictVisible = true
                verdictVerticalOffset = 0
                verdictImpactScale = 1
            }
            VerdictHaptics.impact(for: decision.verdict)
            try? await Task.sleep(for: reduceMotion ? .milliseconds(80) : .milliseconds(350))
        } else {
            await playBinaryVerdictSlam()
            try? await Task.sleep(for: .milliseconds(220))
        }
        guard !Task.isCancelled else { return }
        withAnimation(BWMotion.quietReveal) {
            reactionVisible = true
        }

        try? await Task.sleep(for: reduceMotion ? .milliseconds(80) : .milliseconds(decision.reaction == nil ? 500 : 800))
        guard !Task.isCancelled else { return }
        actionVisible = true
        await Task.yield()
        guard !Task.isCancelled else { return }
        withAnimation(BWMotion.quietReveal) {
            actionOpacity = 1
        }
    }

    @MainActor
    private func playFakeoutTakeover() async {
        let plan = FakeoutMotionPlan(
            preset: fakeoutMotionPreset,
            finalVerdict: decision.verdict,
            playbackSpeed: playbackSpeed
        )

        for step in plan.steps where step.phase != .slam {
#if DEBUG
            animationTrace = animationTrace == "idle"
                ? step.phase.rawValue
                : "\(animationTrace)>\(step.phase.rawValue)"
#endif
            switch step.phase {
            case .preflightDownRight:
                withAnimation(BWMotion.decidingFirstPullAnimation(playbackSpeed: playbackSpeed)) {
                    tensionPull = CGFloat(step.tensionPull)
                }
            case .preflightUpLeft:
                withAnimation(BWMotion.decidingSecondPullAnimation(playbackSpeed: playbackSpeed)) {
                    tensionPull = CGFloat(step.tensionPull)
                }
            case .preflightSettle:
                withAnimation(BWMotion.decidingSettlePullAnimation(playbackSpeed: playbackSpeed)) {
                    tensionPull = CGFloat(step.tensionPull)
                }
            case .commitment:
#if DEBUG
                appendGeometryTrace(step)
#endif
                withAnimation(BWMotion.fakeoutCommitmentAnimation(
                    durationMilliseconds: step.durationMilliseconds
                )) {
                    tensionPull = CGFloat(step.tensionPull)
                    takeoverProgress = CGFloat(step.resolutionProgress)
                }
            case .reversal:
#if DEBUG
                appendGeometryTrace(step)
#endif
                withAnimation(BWMotion.fakeoutReversalAnimation(
                    durationMilliseconds: step.durationMilliseconds
                )) {
                    tensionPull = CGFloat(step.tensionPull)
                    takeoverProgress = CGFloat(step.resolutionProgress)
                }
            case .hold, .preSlamPause:
                break
            case .slam:
                break
            }

            guard await sleep(milliseconds: step.durationMilliseconds) else { return }
        }
    }

#if DEBUG
    private func appendGeometryTrace(_ step: FakeoutMotionStep) {
        let direction = step.tensionPull > 0 ? "down-right" : "up-left"
        let entry = "\(step.phase.rawValue):\(step.targetVerdict.rawValue):\(direction)"
        fakeoutGeometryTrace = fakeoutGeometryTrace == "idle"
            ? entry
            : "\(fakeoutGeometryTrace)>\(entry)"
    }
#endif

    @MainActor
    private func playBinaryVerdictSlam() async {
#if DEBUG
        animationTrace += ">slam"
#endif
        verdictVisible = true
        try? await Task.sleep(for: .milliseconds(16))
        guard !Task.isCancelled else { return }

        VerdictHaptics.prepare(for: decision.verdict, theatricalSlam: true)
        withAnimation(BWMotion.verdictSlamDrop(playbackSpeed: playbackSpeed)) {
            verdictVerticalOffset = 0
            verdictImpactScale = 0.92
        }
        guard await sleep(milliseconds: BWMotion.scaledMilliseconds(400, playbackSpeed: playbackSpeed)) else { return }
        VerdictHaptics.impact(for: decision.verdict, theatricalSlam: true)
        withAnimation(BWMotion.verdictSlamShake(playbackSpeed: playbackSpeed)) {
            impactShakeProgress = 1
        }
        withAnimation(BWMotion.verdictSlamShake(playbackSpeed: playbackSpeed)) {
            verdictRumbleProgress = 1
        }

        withAnimation(BWMotion.verdictSlamRebound(playbackSpeed: playbackSpeed)) {
            verdictVerticalOffset = -6
            verdictImpactScale = 1.04
        }
        guard await sleep(milliseconds: BWMotion.scaledMilliseconds(90, playbackSpeed: playbackSpeed)) else { return }

        withAnimation(BWMotion.verdictSlamSettle(playbackSpeed: playbackSpeed)) {
            verdictVerticalOffset = 0
            verdictImpactScale = 1
        }
        _ = await sleep(milliseconds: BWMotion.scaledMilliseconds(170, playbackSpeed: playbackSpeed))
    }

    private func sleep(milliseconds: Int) async -> Bool {
        guard milliseconds > 0 else { return !Task.isCancelled }
        do {
            try await Task.sleep(for: .milliseconds(milliseconds))
            return !Task.isCancelled
        } catch {
            return false
        }
    }

    private var debugEntranceDelay: Duration {
#if DEBUG
        if CommandLine.arguments.contains("--ui-test-verdict-white")
            || CommandLine.arguments.contains("--ui-test-verdict-black")
            || CommandLine.arguments.contains("--ui-test-verdict-gray") {
            return .milliseconds(650)
        }
#endif
        return .zero
    }
}

private struct VerdictImpactRumbleEffect: GeometryEffect {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let decay = max(0, 1 - progress)
        let horizontal = sin(progress * .pi * 7) * 22 * decay
        let vertical = sin(progress * .pi * 6) * 7 * decay
        let angle = sin(progress * .pi * 6) * 0.038 * decay

        var transform = CGAffineTransform(
            translationX: (size.width / 2) + horizontal,
            y: (size.height / 2) + vertical
        )
        transform = transform.rotated(by: angle)
        transform = transform.translatedBy(x: -size.width / 2, y: -size.height / 2)
        return ProjectionTransform(transform)
    }
}

private struct VerdictSlamShakeEffect: GeometryEffect {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let decay = max(0, 1 - progress)
        let horizontal = sin(progress * .pi * 6) * 16 * decay
        let vertical = sin(progress * .pi * 4) * 6 * decay
        return ProjectionTransform(
            CGAffineTransform(translationX: horizontal, y: vertical)
        )
    }
}

#Preview("Black") {
    VerdictView(decision: .previewBlack, reduceMotion: false, askAgain: {})
}

#Preview("White") {
    VerdictView(decision: .previewWhite, reduceMotion: false, askAgain: {})
}

#Preview("Gray") {
    VerdictView(decision: .previewGray, reduceMotion: false, askAgain: {})
}
