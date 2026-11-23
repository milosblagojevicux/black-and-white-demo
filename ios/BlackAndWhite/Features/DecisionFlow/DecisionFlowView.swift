import SwiftUI

struct DecisionFlowView: View {
    @Bindable var model: DecisionFlowModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var exhaustedHeadlineSize = BWType.exhaustedHeadlineSize
    @ScaledMetric(relativeTo: .title) private var exhaustedResetSize = BWType.exhaustedResetSize
    @ScaledMetric(relativeTo: .title3) private var exhaustedAsideSize = BWType.exhaustedAsideSize
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var inputFocused: Bool
    @ScaledMetric(relativeTo: .largeTitle) private var splashHeadlineSize: CGFloat = 38

    var body: some View {
        ZStack {
            switch model.phase {
            case .splash:
                splash
                    .transition(.opacity)
            case .asking, .submitting:
                asking
                    .transition(.opacity)
            case .deciding:
                deciding
                    .transition(.identity)
            case .verdict(let decision):
                VerdictView(decision: decision, reduceMotion: reduceMotion, askAgain: model.askAgain)
                    .transition(.identity)
            case .error(let error):
                errorView(error)
                    .transition(.opacity)
            case .limitReached(let usage):
                limitReached(usage)
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? .easeOut(duration: 0.12) : BWMotion.stateTransition, value: model.phase)
        .onChange(of: model.focusGeneration, initial: true) { _, _ in
            guard case .asking(.focused) = model.phase else { return }
            Task { @MainActor in
                if model.focusDelay == .zero {
                    try? await Task.sleep(for: .milliseconds(16))
                } else if !reduceMotion {
                    try? await Task.sleep(for: model.focusDelay)
                }
                guard case .asking(.focused) = model.phase else { return }
                inputFocused = true
            }
        }
        .onChange(of: inputFocused) { _, focused in
            guard case .asking = model.phase else { return }
            setAskPresentation(focused ? .focused : .resting)
        }
        .onChange(of: model.phase) { _, phase in
            if phase != .asking(.focused), phase != .submitting {
                inputFocused = false
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.refreshUsageLimitState() }
        }
    }

    private var splash: some View {
        ZStack {
            BWColor.white
                .ignoresSafeArea()

            AskBackdrop()
                .fill(BWColor.black)
                .ignoresSafeArea()

            Text("Life is not\nblack and white.\nThis app is.")
                .font(.system(size: splashHeadlineSize, weight: .bold, design: .default))
                .multilineTextAlignment(.leading)
                .foregroundStyle(BWColor.white)
                .blendMode(.difference)
                .accessibilityAddTraits(.isHeader)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, BWSpacing.extraLarge)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                Button(action: model.startAsking) {
                    Text("Start asking")
                        .font(BWType.button)
                }
                .frame(height: BWLayout.bottomActionHeight)
                .buttonStyle(
                    MonochromeActionButtonStyle(
                        shape: SplashActionSurface(),
                        fill: BWColor.black,
                        foreground: BWColor.white,
                        border: nil
                    )
                )
                .accessibilityIdentifier("start-asking")
                .padding(.leading, BWLayout.splashAndRestingLeading)
                .padding(.trailing, BWSpacing.large)

                Color.clear
                    .frame(height: BWSpacing.small)
            }
        }
    }

    private var asking: some View {
        GeometryReader { geometry in
            let diagonalGeometry = AskDiagonalGeometry(
                contentFrame: geometry.frame(in: .global),
                safeAreaInsets: geometry.safeAreaInsets
            )

            ZStack {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        dismissFocusedAskImmediately()
                    }

                BWColor.white
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                AskBackdrop()
                    .fill(BWColor.black)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                Text(askHeading)
                    .font(.system(.title, design: .default, weight: .bold))
                    .foregroundStyle(BWColor.white)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityLabel(askHeadingAccessibilityLabel)
                    .accessibilityIdentifier("ask-heading")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, BWSpacing.large)
                .padding(.trailing, BWLayout.askHeadingTrailingSafeArea)
                .padding(.top, BWSpacing.large)
                .allowsHitTesting(false)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    questionComposer(diagonalGeometry: diagonalGeometry)
                        .padding(.leading, composerLeadingPadding)
                        .padding(.trailing, composerTrailingPadding)

                    Color.clear
                        .frame(height: BWSpacing.small)
                }
            }
        }
    }

    private var askHeading: String {
        model.unsupportedFormat == nil
            ? "Give me something\nto judge."
            : "Wrong app.\nMake it yes or no."
    }

    private var askHeadingAccessibilityLabel: String {
        model.unsupportedFormat == nil
            ? "Give me something to judge."
            : "Unsupported question format. Rephrase as a yes-or-no question."
    }

    private var composerLeadingPadding: CGFloat {
        switch model.phase {
        case .asking(.resting):
            return BWLayout.splashAndRestingLeading
        case .asking(.focused), .submitting:
            return BWSpacing.small
        default:
            return BWSpacing.large
        }
    }

    private var composerTrailingPadding: CGFloat {
        isFocusedAsk ? BWSpacing.small : BWSpacing.large
    }

    private var isFocusedAsk: Bool {
        model.phase == .asking(.focused) || model.phase == .submitting
    }

    @ViewBuilder
    private func questionComposer(diagonalGeometry: AskDiagonalGeometry) -> some View {
        if isFocusedAsk {
            focusedQuestionComposer
        } else {
            restingQuestionComposer(diagonalGeometry: diagonalGeometry)
        }
    }

    private var focusedQuestionComposer: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                if model.question.isEmpty {
                    Text("Ask me")
                        .font(composerFont)
                        .foregroundStyle(BWColor.black.opacity(0.52))
                        .lineLimit(1...3)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }

                TextField("", text: $model.question, axis: .vertical)
                    .font(composerFont)
                    .foregroundStyle(BWColor.black)
                    .focused($inputFocused)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.go)
                    .lineLimit(1...3)
                    .onSubmit(model.submit)
                    .accessibilityLabel("Question")
                    .accessibilityIdentifier("question-input")
                    .onChange(of: model.question) { _, _ in
                        model.questionDidChange()
                    }
            }
            .padding(.leading, BWLayout.focusedTextLeading)
            .padding(.trailing, BWSpacing.medium)
            .padding(.vertical, BWSpacing.small)
            .frame(maxWidth: .infinity, alignment: .topLeading)

            HStack(spacing: 0) {
                Spacer(minLength: 0)
                submitButton(height: BWLayout.focusedSubmitHeight)
            }
            .frame(height: BWLayout.focusedSubmitHeight)
        }
        .background {
            FocusedAskInputSurface()
                .fill(BWColor.white)
        }
        .overlay {
            FocusedAskInputSurface()
                .stroke(BWColor.black, lineWidth: 2)
        }
    }

    private func restingQuestionComposer(diagonalGeometry: AskDiagonalGeometry) -> some View {
        GeometryReader { geometry in
            let composerFrame = geometry.frame(in: .global)

            ZStack(alignment: .bottomTrailing) {
                AskInputSurface(
                    diagonalGeometry: diagonalGeometry,
                    composerFrame: composerFrame
                )
                .fill(BWColor.white)
                .overlay {
                    AskInputSurface(
                        diagonalGeometry: diagonalGeometry,
                        composerFrame: composerFrame
                    )
                    .stroke(BWColor.black, lineWidth: 2)
                }

                if model.question.isEmpty {
                    Text("Ask me")
                        .font(BWType.restingComposer)
                        .foregroundStyle(BWColor.black.opacity(0.52))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .padding(.leading, BWLayout.composerTextLeading)
                        .padding(.trailing, BWLayout.composerTextTrailing)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }

                TextField("", text: $model.question)
                    .font(BWType.restingComposer)
                    .foregroundStyle(BWColor.black)
                    .focused($inputFocused)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.go)
                    .lineLimit(1)
                    .padding(.leading, BWLayout.composerTextLeading)
                    .padding(.trailing, BWLayout.composerTextTrailing)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .onSubmit(model.submit)
                    .simultaneousGesture(TapGesture().onEnded(model.focusRestingAsk))
                    .accessibilityLabel("Question")
                    .accessibilityIdentifier("question-input")
                    .onChange(of: model.question) { _, _ in
                        model.questionDidChange()
                    }

                submitButton(height: BWLayout.bottomActionHeight)
            }
        }
        .frame(height: BWLayout.bottomActionHeight)
    }

    @ViewBuilder
    private func submitButton(height: CGFloat) -> some View {
        if model.phase == .submitting {
            ZStack {
                AskSubmitSurface()
                    .fill(BWColor.black)
                    .overlay {
                        AskSubmitSurface()
                            .stroke(BWColor.black, lineWidth: 2)
                    }

                PendingDecisionThinkingMark(reduceMotion: reduceMotion)
                    .frame(width: 68)
                    .frame(maxHeight: .infinity)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(width: BWLayout.submitWidth, height: height)
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Loading decision")
            .accessibilityRespondsToUserInteraction(false)
            .accessibilityIdentifier("decision-loading")
        } else {
            Button(action: model.submit) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 19, weight: .semibold))
                    .frame(width: 68)
                    .frame(maxHeight: .infinity)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(width: BWLayout.submitWidth, height: height)
            .buttonStyle(
                MonochromeActionButtonStyle(
                    shape: AskSubmitSurface(),
                    fill: BWColor.black,
                    foreground: BWColor.white,
                    border: BWColor.black,
                    becomesOutlineWhenPressed: false,
                    pressedFill: BWColor.white,
                    pressedForeground: BWColor.black
                )
            )
            .accessibilityLabel("Submit question")
            .accessibilityIdentifier("submit-question")
        }
    }

    private var composerFont: Font {
        isFocusedAsk ? .system(.title3, design: .default, weight: .bold) : BWType.body
    }

    private func dismissFocusedAskImmediately() {
        guard case .asking(.focused) = model.phase else { return }

        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            inputFocused = false
            model.dismissFocusedAsk()
        }
    }

    private func setAskPresentation(_ presentation: AskPresentation) {
        guard presentation == .resting else {
            model.setAskPresentation(presentation)
            return
        }

        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            model.setAskPresentation(.resting)
        }
    }

    private var deciding: some View {
        DecisionTakeoverView(reduceMotion: reduceMotion)
    }

    private func errorView(_ error: DecisionFlowError) -> some View {
        ZStack {
            BWColor.black
                .ignoresSafeArea()

            Text(error.message)
                .font(.system(size: 64, weight: .black, design: .default))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, BWSpacing.large)
                .accessibilityAddTraits(.isHeader)
        }
        .foregroundStyle(BWColor.white)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                PrimaryActionButton(
                    title: "Try again",
                    foreground: BWColor.black,
                    background: BWColor.white,
                    action: model.recover
                )
                .padding(.horizontal, BWSpacing.medium)

                Color.clear
                    .frame(height: BWSpacing.small)
            }
        }
    }

    private func limitReached(_ usage: Usage) -> some View {
        ZStack {
            BWColor.black
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: BWSpacing.medium) {
                Text("I've judged enough for today.")
                    .font(.system(size: exhaustedHeadlineSize, weight: .black, design: .default))
                    .accessibilityAddTraits(.isHeader)
                Text(limitResetCopy(for: usage.resetsAt))
                    .font(.system(size: exhaustedResetSize, weight: .bold, design: .default))
                Text("You're on your own until then.")
                    .font(.system(size: exhaustedAsideSize, weight: .regular, design: .default))
            }
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, BWSpacing.large)
        }
        .foregroundStyle(BWColor.white)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("usage-exhausted")
    }

    private func limitResetCopy(for resetsAt: Date) -> String {
        UsageLimitCopy.resetLine(resetsAt: resetsAt, now: Date())
    }
}

enum UsageLimitCopy {
    static func resetLine(
        resetsAt: Date,
        now: Date,
        calendar: Calendar = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        var calendar = calendar
        calendar.timeZone = timeZone
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        if calendar.isDate(resetsAt, inSameDayAs: calendar.date(byAdding: .day, value: 1, to: now)!) {
            return "Back tomorrow at \(formatter.string(from: resetsAt))."
        }
        if calendar.isDate(resetsAt, inSameDayAs: now) { return "Back today at \(formatter.string(from: resetsAt))." }
        formatter.dateStyle = .medium
        return "Back \(formatter.string(from: resetsAt))."
    }
}

struct PendingDecisionThinkingMark: View {
    let preset: LoadingMotionPreset
    let playbackSpeed: Double
    let reduceMotion: Bool
    let replayToken: Int
    @State private var epoch = Date()

    nonisolated static func animationEnabled(reduceMotion: Bool) -> Bool { !reduceMotion }

    nonisolated static func animationTime(
        elapsed: TimeInterval,
        playbackSpeed: Double,
        reduceMotion: Bool
    ) -> TimeInterval {
        reduceMotion ? 0 : max(0, elapsed) * max(0, playbackSpeed)
    }

    init(
        preset: LoadingMotionPreset = .production,
        playbackSpeed: Double = 1,
        reduceMotion: Bool,
        replayToken: Int = 0
    ) {
        self.preset = preset
        self.playbackSpeed = playbackSpeed
        self.reduceMotion = reduceMotion
        self.replayToken = replayToken
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
            Canvas { context, canvasSize in
                let elapsed = timeline.date.timeIntervalSince(epoch)
                let time = Self.animationTime(
                    elapsed: elapsed,
                    playbackSpeed: playbackSpeed,
                    reduceMotion: reduceMotion
                )
                let paths = preset.blobs.enumerated().map { index, blob in
                    blobPath(index: index, preset: blob, time: time, size: canvasSize)
                }
                let centerPath = blobPath(
                    index: 3,
                    preset: preset.centerBlob,
                    time: time,
                    size: canvasSize,
                    radiusRatio: preset.centerRatio,
                    inset: 0
                )

                for operation in LoadingMotionRenderPlan.operations {
                    switch operation {
                    case .fill(let blob):
                        context.fill(paths[blob], with: .color(BWColor.white))
                    case .outline(let blob):
                        context.stroke(
                            paths[blob],
                            with: .color(BWColor.black),
                            style: StrokeStyle(
                                lineWidth: CGFloat(preset.outlineWidth),
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                    case .centerCover:
                        context.fill(centerPath, with: .color(BWColor.black))
                    }
                }
            }
        }
        .frame(width: CGFloat(preset.size), height: CGFloat(preset.size))
        .shadow(
            color: BWColor.white.opacity(reduceMotion ? preset.glowOpacity * 0.5 : preset.glowOpacity),
            radius: CGFloat(reduceMotion ? min(preset.glowRadius, 1) : preset.glowRadius)
        )
        .accessibilityHidden(true)
        .onChange(of: replayToken) { _, _ in
            epoch = Date()
        }
    }

    private func blobPath(
        index: Int,
        preset blob: LoadingMotionBlobPreset,
        time: TimeInterval,
        size: CGSize,
        radiusRatio: Double = 1,
        inset: CGFloat? = nil
    ) -> Path {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let baseRadius = Double(
            min(size.width, size.height) / 2 * CGFloat(radiusRatio)
                - (inset ?? CGFloat(preset.outlineWidth))
        )
        let phase = blob.phase * 2 * .pi
        let morph = time * blob.speed * 2 * .pi
        let rotation = time * blob.slowRotation * 2 * .pi
        let sampleCount = 96

        return Path { path in
            for sample in 0...sampleCount {
                let angle = Double(sample) / Double(sampleCount) * 2 * .pi
                let wave = deformation(
                    index: index,
                    angle: angle,
                    morph: morph,
                    phase: phase
                )
                let radius = baseRadius * (1 + blob.deformationAmplitude * wave)
                let renderedAngle = angle + rotation
                let point = CGPoint(
                    x: center.x + CGFloat(radius * cos(renderedAngle)),
                    y: center.y + CGFloat(radius * sin(renderedAngle))
                )
                if sample == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
            path.closeSubpath()
        }
    }

    private func deformation(
        index: Int,
        angle: Double,
        morph: Double,
        phase: Double
    ) -> Double {
        switch index {
        case 0:
            return 0.62 * sin(3 * angle + morph + phase)
                + 0.38 * cos(5 * angle - morph * 0.7 + phase)
        case 1:
            return 0.55 * cos(4 * angle - morph * 0.82 + phase)
                + 0.45 * sin(7 * angle + morph * 0.48 - phase)
        case 2:
            return 0.68 * sin(2 * angle + morph * 1.12 + phase)
                + 0.32 * cos(6 * angle - morph * 0.56 + phase)
        default:
            return 0.58 * cos(3 * angle + morph * 0.74 + phase)
                + 0.42 * sin(6 * angle - morph * 0.64 - phase)
        }
    }
}

private struct DecisionTakeoverView: View {
    let reduceMotion: Bool

    @State private var pull: CGFloat = 0

    var body: some View {
        ZStack {
            BWColor.white
                .ignoresSafeArea()

            DecisionTensionBackdrop(pull: pull)
                .fill(BWColor.black)
                .ignoresSafeArea()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Deciding")
        .accessibilityIdentifier("deciding-takeover")
        .task(id: reduceMotion) {
            pull = 0
            guard !reduceMotion else { return }

            if debugMotionStartDelay > .zero {
                guard await sleep(for: debugMotionStartDelay) else { return }
            }

            while !Task.isCancelled {
                withAnimation(BWMotion.decidingFirstPull) {
                    pull = BWMotion.decidingDownRightPull
                }
                guard await sleep(for: BWMotion.decidingFirstPullBeat) else { return }

                withAnimation(BWMotion.decidingSecondPull) {
                    pull = BWMotion.decidingUpLeftOvershootPull
                }
                guard await sleep(for: BWMotion.decidingSecondPullBeat) else { return }

                withAnimation(BWMotion.decidingSettlePull) {
                    pull = BWMotion.decidingUpLeftSettledPull
                }
                guard await sleep(for: BWMotion.decidingSettlePullBeat) else { return }
            }
        }
    }

    private func sleep(for duration: Duration) async -> Bool {
        do {
            try await Task.sleep(for: duration)
            return !Task.isCancelled
        } catch {
            return false
        }
    }

    private var debugMotionStartDelay: Duration {
#if DEBUG
        if CommandLine.arguments.contains("--ui-test-deciding") {
            return .milliseconds(650)
        }
#endif
        return .zero
    }
}

struct DecisionTensionBackdrop: Shape {
    var pull: CGFloat
    var resolution: Verdict?
    var resolutionProgress: CGFloat

    init(
        pull: CGFloat,
        resolution: Verdict? = nil,
        resolutionProgress: CGFloat = 0
    ) {
        self.pull = pull
        self.resolution = resolution
        self.resolutionProgress = resolutionProgress
    }

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(pull, resolutionProgress) }
        set {
            pull = newValue.first
            resolutionProgress = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let geometry = geometry(in: rect)
        let effectiveResolution = geometry.effectiveResolution

        return Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            if effectiveResolution == .black {
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            }
            path.addLine(to: geometry.start)
            path.addCurve(
                to: geometry.midpoint,
                control1: geometry.firstOuterControl,
                control2: geometry.firstInnerControl
            )
            path.addCurve(
                to: geometry.end,
                control1: geometry.secondInnerControl,
                control2: geometry.secondOuterControl
            )
            if effectiveResolution == .black {
                path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            }
            path.closeSubpath()
        }
    }

    func geometry(in rect: CGRect) -> DecisionTensionGeometry {
        let boundedPull = min(max(pull, -1), 1)
        let boundedResolution = min(abs(resolutionProgress), 1)
        let effectiveResolution = resolutionProgress < 0
            ? oppositeBinaryResolution
            : resolution
        let baseStart = CGPoint(x: rect.maxX, y: rect.minY)
        let baseEnd = CGPoint(x: rect.minX, y: rect.maxY)
        let baseMidpoint = CGPoint(x: rect.midX, y: rect.midY)
        let target = resolutionTarget(for: effectiveResolution, in: rect)
        let start = interpolate(baseStart, target.start, progress: boundedResolution)
        let end = interpolate(baseEnd, target.end, progress: boundedResolution)
        let committedMidpoint = interpolate(baseMidpoint, target.midpoint, progress: boundedResolution)
        let elasticDisplacement = min(rect.width, rect.height)
            * 0.14
            * boundedPull
            * (1 - boundedResolution)
        let pulledMidpoint = CGPoint(
            x: committedMidpoint.x + elasticDisplacement,
            y: committedMidpoint.y + elasticDisplacement
        )
        let tangentScale: CGFloat = 0.12
        let tangent = CGVector(
            dx: (end.x - start.x) * tangentScale,
            dy: (end.y - start.y) * tangentScale
        )
        let firstOuterControl = CGPoint(
            x: start.x + ((pulledMidpoint.x - start.x) * 0.34),
            y: start.y + ((pulledMidpoint.y - start.y) * 0.34)
        )
        let firstInnerControl = CGPoint(
            x: pulledMidpoint.x - tangent.dx,
            y: pulledMidpoint.y - tangent.dy
        )
        let secondInnerControl = CGPoint(
            x: pulledMidpoint.x + tangent.dx,
            y: pulledMidpoint.y + tangent.dy
        )
        let secondOuterControl = CGPoint(
            x: end.x - ((end.x - pulledMidpoint.x) * 0.34),
            y: end.y - ((end.y - pulledMidpoint.y) * 0.34)
        )

        return DecisionTensionGeometry(
            effectiveResolution: effectiveResolution,
            start: start,
            midpoint: pulledMidpoint,
            end: end,
            firstOuterControl: firstOuterControl,
            firstInnerControl: firstInnerControl,
            secondInnerControl: secondInnerControl,
            secondOuterControl: secondOuterControl
        )
    }

    private var oppositeBinaryResolution: Verdict? {
        switch resolution {
        case .white: .black
        case .black: .white
        case .gray: .gray
        case nil: nil
        }
    }

    private func resolutionTarget(
        for effectiveResolution: Verdict?,
        in rect: CGRect
    ) -> (start: CGPoint, midpoint: CGPoint, end: CGPoint) {
        switch effectiveResolution {
        case .white:
            let corner = CGPoint(x: rect.minX, y: rect.minY)
            return (corner, corner, corner)
        case .black:
            let corner = CGPoint(x: rect.maxX, y: rect.maxY)
            return (corner, corner, corner)
        case .gray, .none:
            return (
                CGPoint(x: rect.maxX, y: rect.minY),
                CGPoint(x: rect.midX, y: rect.midY),
                CGPoint(x: rect.minX, y: rect.maxY)
            )
        }
    }

    private func interpolate(_ from: CGPoint, _ to: CGPoint, progress: CGFloat) -> CGPoint {
        CGPoint(
            x: from.x + ((to.x - from.x) * progress),
            y: from.y + ((to.y - from.y) * progress)
        )
    }
}

struct DecisionTensionGeometry {
    let effectiveResolution: Verdict?
    let start: CGPoint
    let midpoint: CGPoint
    let end: CGPoint
    let firstOuterControl: CGPoint
    let firstInnerControl: CGPoint
    let secondInnerControl: CGPoint
    let secondOuterControl: CGPoint
}

private struct AskBackdrop: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

struct SplashActionSurface: Shape {
    func path(in rect: CGRect) -> Path {
        let slant = BWLayout.actionSlant
        return Path { path in
            path.move(to: CGPoint(x: rect.minX + slant, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

struct AskDiagonalGeometry: Equatable {
    let canvasFrame: CGRect

    init(canvasFrame: CGRect) {
        self.canvasFrame = canvasFrame
    }

    init(contentFrame: CGRect, safeAreaInsets: EdgeInsets) {
        canvasFrame = CGRect(
            x: contentFrame.minX - safeAreaInsets.leading,
            y: contentFrame.minY - safeAreaInsets.top,
            width: contentFrame.width + safeAreaInsets.leading + safeAreaInsets.trailing,
            height: contentFrame.height + safeAreaInsets.top + safeAreaInsets.bottom
        )
    }

    func boundaryX(atGlobalY globalY: CGFloat) -> CGFloat {
        let progress = (globalY - canvasFrame.minY) / max(canvasFrame.height, 1)
        return canvasFrame.maxX - (progress * canvasFrame.width)
    }

    func localBoundaryX(
        atGlobalY globalY: CGFloat,
        in frame: CGRect,
        perpendicularClearance: CGFloat = 0
    ) -> CGFloat {
        boundaryX(atGlobalY: globalY)
            + horizontalOffset(forPerpendicularClearance: perpendicularClearance)
            - frame.minX
    }

    private func horizontalOffset(forPerpendicularClearance clearance: CGFloat) -> CGFloat {
        let slope = canvasFrame.width / max(canvasFrame.height, 1)
        return clearance * sqrt(1 + (slope * slope))
    }
}

private struct AskInputSurface: Shape {
    let diagonalGeometry: AskDiagonalGeometry
    let composerFrame: CGRect

    func path(in rect: CGRect) -> Path {
        let topLeading = diagonalGeometry.localBoundaryX(
            atGlobalY: composerFrame.minY,
            in: composerFrame,
            perpendicularClearance: BWLayout.restingDiagonalClearance
        )
        let bottomLeading = diagonalGeometry.localBoundaryX(
            atGlobalY: composerFrame.maxY,
            in: composerFrame,
            perpendicularClearance: BWLayout.restingDiagonalClearance
        )

        return Path { path in
            path.move(to: CGPoint(x: topLeading, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: bottomLeading, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

private struct FocusedAskInputSurface: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX + BWLayout.focusedInputLeadingSlant, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

private struct AskSubmitSurface: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX + BWLayout.actionSlant, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

#Preview {
    DecisionFlowView(model: DecisionFlowModel(service: MockDecisionService()))
}
