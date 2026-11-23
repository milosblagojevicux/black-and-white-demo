import SwiftUI
#if DEBUG
import UIKit
#endif

struct RootView: View {
    @State private var model: DecisionFlowModel

    init(environment: AppEnvironment) {
        _model = State(
            initialValue: DecisionFlowModel(
                service: environment.decisionService,
                dailyContextStore: environment.dailyContextStore,
                reactionContextStore: environment.reactionContextStore,
                initialPhase: Self.initialPhase,
                standardDecisionBeat: Self.standardDecisionBeat
            )
        )
    }

    var body: some View {
#if DEBUG
        if LoadingMotionLabAvailability.shouldPresent(arguments: CommandLine.arguments) {
            LoadingMotionLabView()
                .preferredColorScheme(.dark)
        } else if FullWidthVerdictLabAvailability.shouldPresent(arguments: CommandLine.arguments) {
            FullWidthVerdictLabView()
                .preferredColorScheme(.dark)
        } else if FakeoutMotionLabAvailability.shouldPresent(arguments: CommandLine.arguments) {
            FakeoutMotionLabView()
                .preferredColorScheme(.dark)
        } else {
            productionRoot
        }
#else
        productionRoot
#endif
    }

    private var productionRoot: some View {
        DecisionFlowView(model: model)
            .preferredColorScheme(.dark)
    }

#if DEBUG
private struct FullWidthVerdictLabView: View {
    private struct Fixture: Identifiable {
        let id: String
        let title: String
        let text: String
    }

    private let fixtures = [
        Fixture(id: "en-short", title: "English short", text: "Yes."),
        Fixture(id: "en-long", title: "English long", text: "Absolutely."),
        Fixture(id: "sr-latn", title: "Serbian Latin", text: "Nije baš tako jednostavno."),
        Fixture(id: "sr-cyrl", title: "Serbian Cyrillic", text: "Није баш тако једноставно."),
        Fixture(id: "ru", title: "Cyrillic", text: "Конечно."),
        Fixture(id: "ar", title: "Arabic RTL", text: "نعم."),
        Fixture(id: "he", title: "Hebrew RTL", text: "כן."),
        Fixture(id: "ja", title: "Japanese", text: "はい。"),
        Fixture(id: "extreme", title: "Extreme", text: "This verdict is deliberately too long.")
    ]

    @State private var fixtureID = "en-short"
    @State private var localeTag = "en"
    @State private var customText = "Yes."
    @State private var isWhiteVerdict = true
    @State private var horizontalInset = 24.0
    @State private var availableHeight = 260.0

    private var targetWidth: CGFloat {
        max(1, UIScreen.main.bounds.width - horizontalInset * 2)
    }

    private var metrics: FullWidthVerdictTextMetrics {
        FullWidthVerdictTextSizing.metrics(
            text: customText,
            targetWidth: targetWidth,
            availableHeight: availableHeight
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                isWhiteVerdict ? BWColor.white : BWColor.black
                FullWidthVerdictText(
                    text: customText,
                    targetWidth: targetWidth,
                    availableHeight: availableHeight,
                    foreground: isWhiteVerdict ? BWColor.black : BWColor.white,
                    accessibilityLabel: "Verdict preview: \(customText)"
                )
            }
            .frame(height: max(availableHeight + 48, 260))

            ScrollView {
                VStack(alignment: .leading, spacing: BWSpacing.medium) {
                    Text("Verdict Typography Lab")
                        .font(BWType.button)

                    Picker("Fixture", selection: $fixtureID) {
                        ForEach(fixtures) { fixture in
                            Text(fixture.title).tag(fixture.id)
                        }
                    }
                    .onChange(of: fixtureID) { _, id in
                        customText = fixtures.first(where: { $0.id == id })?.text ?? customText
                    }

                    Picker("Locale", selection: $localeTag) {
                        Text("English").tag("en")
                        Text("Serbian Latin").tag("sr-Latn")
                        Text("Serbian Cyrillic").tag("sr-Cyrl")
                        Text("Arabic").tag("ar")
                        Text("Hebrew").tag("he")
                        Text("Japanese").tag("ja")
                    }

                    TextField("Custom verdict text", text: $customText)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("verdict-typography-custom-text")

                    Toggle("White verdict background", isOn: $isWhiteVerdict)
                        .tint(BWColor.white)
                    slider("Horizontal inset", value: $horizontalInset, range: 8...56, step: 1, unit: "pt")
                    slider("Available height", value: $availableHeight, range: 80...420, step: 1, unit: "pt")

                    metric("Target width", value: targetWidth, unit: "pt")
                    metric("Measured width", value: metrics.measuredWidth, unit: "pt")
                    metric("Computed font size", value: metrics.fontSize, unit: "pt")
                    metric("Measured height", value: metrics.measuredHeight, unit: "pt")
                    Text(metrics.constraintWarning ?? "Fits the width and height target.")
                        .foregroundStyle(metrics.constraintWarning == nil ? BWColor.white.opacity(0.72) : BWColor.white)
                        .accessibilityIdentifier("verdict-typography-warning")
                }
                .padding(BWSpacing.medium)
            }
            .foregroundStyle(BWColor.white)
            .background(BWColor.black)
        }
        .background(BWColor.black.ignoresSafeArea())
        .accessibilityIdentifier("verdict-typography-lab")
    }

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, unit: String) -> some View {
        VStack(alignment: .leading, spacing: BWSpacing.small) {
            HStack { Text(title); Spacer(); Text("\(Int(value.wrappedValue)) \(unit)").monospacedDigit() }
            Slider(value: value, in: range, step: step).tint(BWColor.white)
        }
    }

    private func metric(_ title: String, value: CGFloat, unit: String) -> some View {
        HStack { Text(title); Spacer(); Text("\(value, format: .number.precision(.fractionLength(1))) \(unit)").monospacedDigit() }
    }
}

#endif

    private static var initialPhase: DecisionFlowPhase {
#if DEBUG
        if CommandLine.arguments.contains("--ui-test-verdict-white") {
            return .verdict(.previewWhite)
        }
        if CommandLine.arguments.contains("--ui-test-verdict-black") {
            return .verdict(.previewBlack)
        }
        if CommandLine.arguments.contains("--ui-test-verdict-gray") {
            return .verdict(.previewGray)
        }
        if CommandLine.arguments.contains("--ui-test-error") {
            return .error(.connection)
        }
        if CommandLine.arguments.contains("--ui-test-paused") {
            return .error(.paused)
        }
        if CommandLine.arguments.contains("--ui-test-usage-warning") {
            return .verdict(.previewWarning)
        }
        if CommandLine.arguments.contains("--ui-test-usage-last") {
            return .verdict(.previewLast)
        }
        if CommandLine.arguments.contains("--ui-test-usage-exhausted") {
            return .limitReached(Usage(remainingToday: 0, state: .exhausted, resetsAt: .distantFuture))
        }
        if CommandLine.arguments.contains("--ui-test-deciding") {
            return .deciding
        }
        if CommandLine.arguments.contains("--ui-test-ask-resting") {
            return .asking(.resting)
        }
        if CommandLine.arguments.contains("--ui-test-motion-black")
            || CommandLine.arguments.contains("--ui-test-verdict-fakeout")
            || CommandLine.arguments.contains("--ui-test-unsupported-suggestion")
            || CommandLine.arguments.contains("--ui-test-pending-standard")
            || CommandLine.arguments.contains("--ui-test-pending-instant")
            || CommandLine.arguments.contains("--ui-test-pending-fakeout")
            || CommandLine.arguments.contains("--ui-test-loading-error") {
            return .asking(.focused)
        }
#endif
        return .splash
    }

    private static var standardDecisionBeat: Duration {
#if DEBUG
        if CommandLine.arguments.contains("--ui-test-pending-standard") {
            return .milliseconds(1_200)
        }
#endif
        return .milliseconds(350)
    }
}

#Preview {
    RootView(environment: AppEnvironment(decisionService: MockDecisionService()))
}

#if DEBUG
private struct LoadingMotionLabView: View {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var settings = LoadingMotionLabSettings()
    @State private var replayID = 0
    @State private var copied = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                BWColor.black
                PendingDecisionThinkingMark(
                    preset: settings.preset,
                    playbackSpeed: settings.playbackSpeed.rawValue,
                    reduceMotion: systemReduceMotion || settings.reduceMotionPreview,
                    replayToken: replayID
                )
            }
            .frame(maxWidth: .infinity, minHeight: 150)

            controls
        }
        .background(BWColor.black.ignoresSafeArea())
        .accessibilityIdentifier("loading-motion-lab")
    }

    private var controls: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BWSpacing.medium) {
                HStack {
                    Text("Loading Motion Lab")
                        .font(BWType.button)
                    Spacer()
                    Button("Replay", action: replay)
                        .buttonStyle(MotionLabButtonStyle(emphasized: true))
                        .accessibilityIdentifier("loading-motion-lab-replay")
                }

                Picker("Playback", selection: $settings.playbackSpeed) {
                    ForEach(LoadingMotionPlaybackSpeed.allCases) { speed in
                        Text(speed.label).tag(speed)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("Reduce Motion preview", isOn: $settings.reduceMotionPreview)
                    .tint(BWColor.white)

                Text("Experimental review controls. Reset restores the current production review baseline; neither the initial lab values nor later tuning is approved automatically.")
                    .font(.footnote)
                    .foregroundStyle(BWColor.white.opacity(0.72))

                slider("Size", value: presetBinding(\.size), range: 26...38, step: 1)
                slider("Center ratio", value: presetBinding(\.centerRatio), range: 0.50...0.68, step: 0.01)
                slider("Outline", value: presetBinding(\.outlineWidth), range: 0.5...1.5, step: 0.05)

                ForEach(0..<3, id: \.self) { index in
                    VStack(alignment: .leading, spacing: BWSpacing.small) {
                        Text("Blob \(index + 1)")
                            .font(BWType.button)
                        slider("Deformation", value: blobBinding(index, \.deformationAmplitude), range: 0...0.2, step: 0.01)
                        slider("Speed", value: blobBinding(index, \.speed), range: 0.1...1.5, step: 0.05)
                        slider("Phase", value: blobBinding(index, \.phase), range: 0...1, step: 0.01)
                        slider("Slow rotation", value: blobBinding(index, \.slowRotation), range: -0.08...0.08, step: 0.005)
                    }
                }

                VStack(alignment: .leading, spacing: BWSpacing.small) {
                    Text("Center blob")
                        .font(BWType.button)
                    slider("Deformation", value: centerBlobBinding(\.deformationAmplitude), range: 0...0.2, step: 0.01)
                    slider("Speed", value: centerBlobBinding(\.speed), range: 0.1...1.5, step: 0.05)
                    slider("Phase", value: centerBlobBinding(\.phase), range: 0...1, step: 0.01)
                    slider("Slow rotation", value: centerBlobBinding(\.slowRotation), range: -0.08...0.08, step: 0.005)
                }

                slider("Glow radius", value: presetBinding(\.glowRadius), range: 0...6, step: 0.25)
                slider("Glow opacity", value: presetBinding(\.glowOpacity), range: 0...0.6, step: 0.02)

                HStack {
                    Button("Reset to production") {
                        settings.resetToProductionDefaults()
                        replay()
                    }
                    .buttonStyle(MotionLabButtonStyle())
                    .accessibilityIdentifier("loading-motion-lab-reset")

                    Spacer()

                    Button(copied ? "Copied" : "Copy preset") {
                        UIPasteboard.general.string = settings.preset.swiftInitializer
                        copied = true
                    }
                    .buttonStyle(MotionLabButtonStyle())
                    .accessibilityIdentifier("loading-motion-lab-copy")
                }
            }
            .padding(BWSpacing.medium)
        }
        .foregroundStyle(BWColor.white)
        .background(BWColor.black)
    }

    private func slider(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: BWSpacing.small) {
            HStack {
                Text(title)
                Spacer()
                Text(value.wrappedValue, format: .number.precision(.fractionLength(0...3)))
                    .monospacedDigit()
            }
            Slider(value: value, in: range, step: step)
                .tint(BWColor.white)
                .accessibilityLabel(title)
                .accessibilityValue(value.wrappedValue.formatted(.number.precision(.fractionLength(0...3))))
        }
    }

    private func presetBinding(
        _ keyPath: WritableKeyPath<LoadingMotionPresetValues, Double>
    ) -> Binding<Double> {
        Binding(
            get: { LoadingMotionPresetValues(settings.preset)[keyPath: keyPath] },
            set: { newValue in
                var values = LoadingMotionPresetValues(settings.preset)
                values[keyPath: keyPath] = newValue
                settings.preset = values.preset
                copied = false
            }
        )
    }

    private func blobBinding(
        _ index: Int,
        _ keyPath: WritableKeyPath<LoadingMotionBlobPresetValues, Double>
    ) -> Binding<Double> {
        Binding(
            get: { LoadingMotionPresetValues(settings.preset).blobs[index][keyPath: keyPath] },
            set: { newValue in
                var values = LoadingMotionPresetValues(settings.preset)
                values.blobs[index][keyPath: keyPath] = newValue
                settings.preset = values.preset
                copied = false
            }
        )
    }

    private func centerBlobBinding(
        _ keyPath: WritableKeyPath<LoadingMotionBlobPresetValues, Double>
    ) -> Binding<Double> {
        Binding(
            get: { LoadingMotionBlobPresetValues(settings.preset.centerBlob)[keyPath: keyPath] },
            set: { newValue in
                var values = LoadingMotionBlobPresetValues(settings.preset.centerBlob)
                values[keyPath: keyPath] = newValue
                var presetValues = LoadingMotionPresetValues(settings.preset)
                presetValues.centerBlob = values
                settings.preset = presetValues.preset
                copied = false
            }
        )
    }

    private func replay() {
        replayID += 1
        copied = false
    }
}

private struct LoadingMotionBlobPresetValues {
    var deformationAmplitude: Double
    var speed: Double
    var phase: Double
    var slowRotation: Double

    init(_ preset: LoadingMotionBlobPreset) {
        deformationAmplitude = preset.deformationAmplitude
        speed = preset.speed
        phase = preset.phase
        slowRotation = preset.slowRotation
    }

    var preset: LoadingMotionBlobPreset {
        LoadingMotionBlobPreset(
            deformationAmplitude: deformationAmplitude,
            speed: speed,
            phase: phase,
            slowRotation: slowRotation
        )
    }
}

private struct LoadingMotionPresetValues {
    var size: Double
    var centerRatio: Double
    var outlineWidth: Double
    var blobs: [LoadingMotionBlobPresetValues]
    var centerBlob: LoadingMotionBlobPresetValues
    var glowRadius: Double
    var glowOpacity: Double

    init(_ preset: LoadingMotionPreset) {
        size = preset.size
        centerRatio = preset.centerRatio
        outlineWidth = preset.outlineWidth
        blobs = preset.blobs.map(LoadingMotionBlobPresetValues.init)
        centerBlob = LoadingMotionBlobPresetValues(preset.centerBlob)
        glowRadius = preset.glowRadius
        glowOpacity = preset.glowOpacity
    }

    var preset: LoadingMotionPreset {
        LoadingMotionPreset(
            size: size,
            centerRatio: centerRatio,
            outlineWidth: outlineWidth,
            firstBlob: blobs[0].preset,
            secondBlob: blobs[1].preset,
            thirdBlob: blobs[2].preset,
            centerBlob: centerBlob.preset,
            glowRadius: glowRadius,
            glowOpacity: glowOpacity
        )
    }
}

private struct FakeoutMotionLabView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var settings = FakeoutMotionLabSettings()
    @State private var finalVerdict = Verdict.black
    @State private var replayID = 0
    @State private var copied = false

    var body: some View {
        VStack(spacing: 0) {
            VerdictView(
                decision: decision,
                reduceMotion: reduceMotion,
                fakeoutMotionPreset: settings.preset,
                playbackSpeed: settings.playbackSpeed.rawValue,
                askAgain: replay
            )
            .id(replayID)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            controls
                .frame(maxHeight: 430)
        }
        .background(BWColor.black.ignoresSafeArea())
        .accessibilityIdentifier("fakeout-motion-lab")
    }

    private var controls: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BWSpacing.medium) {
                HStack {
                    Text("V1 Fakeout Motion Lab")
                        .font(BWType.button)
                    Spacer()
                    Button("Replay", action: replay)
                        .buttonStyle(MotionLabButtonStyle(emphasized: true))
                        .accessibilityIdentifier("motion-lab-replay")
                }

                Picker("Final verdict", selection: $finalVerdict) {
                    Text("Black").tag(Verdict.black)
                    Text("White").tag(Verdict.white)
                }
                .pickerStyle(.segmented)
                .onChange(of: finalVerdict) { _, _ in replay() }

                Picker("Speed", selection: $settings.playbackSpeed) {
                    ForEach(FakeoutMotionPlaybackSpeed.allCases) { speed in
                        Text(speed.label).tag(speed)
                    }
                }
                .pickerStyle(.segmented)

                Text("Two normal 420 ms deciding pull cycles always play first. These controls tune only the post-cycle fake-out.")
                    .font(.footnote)
                    .foregroundStyle(BWColor.white.opacity(0.72))

                amountSlider
                millisecondSlider(
                    title: "Post-cycle commitment",
                    value: presetIntegerBinding(\.commitmentMilliseconds),
                    range: 0...600
                )
                millisecondSlider(
                    title: "Hold",
                    value: presetIntegerBinding(\.holdMilliseconds),
                    range: 0...600
                )
                millisecondSlider(
                    title: "Reversal",
                    value: presetIntegerBinding(\.reversalMilliseconds),
                    range: 0...400
                )
                millisecondSlider(
                    title: "Pre-slam pause",
                    value: presetIntegerBinding(\.preSlamPauseMilliseconds),
                    range: 0...300
                )

                HStack {
                    Button("Reset") {
                        settings.resetToProductionDefaults()
                        replay()
                    }
                    .buttonStyle(MotionLabButtonStyle())
                    .accessibilityIdentifier("motion-lab-reset")

                    Spacer()

                    Button(copied ? "Copied" : "Copy preset") {
                        UIPasteboard.general.string = settings.preset.swiftInitializer
                        copied = true
                    }
                    .buttonStyle(MotionLabButtonStyle())
                    .accessibilityIdentifier("motion-lab-copy")
                }
            }
            .padding(BWSpacing.medium)
        }
        .foregroundStyle(BWColor.white)
        .background(BWColor.black)
    }

    private var amountSlider: some View {
        VStack(alignment: .leading, spacing: BWSpacing.small) {
            HStack {
                Text("Misdirection amount")
                Spacer()
                Text(settings.preset.misdirectionAmount, format: .percent.precision(.fractionLength(0)))
                    .monospacedDigit()
            }
            Slider(value: presetDoubleBinding(\.misdirectionAmount), in: 0...1, step: 0.05)
                .tint(BWColor.white)
                .accessibilityLabel("Misdirection amount")
                .accessibilityValue(
                    Text(
                        settings.preset.misdirectionAmount,
                        format: .percent.precision(.fractionLength(0))
                    )
                )
        }
    }

    private func millisecondSlider(
        title: String,
        value: Binding<Int>,
        range: ClosedRange<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: BWSpacing.small) {
            HStack {
                Text(title)
                Spacer()
                Text("\(value.wrappedValue) ms")
                    .monospacedDigit()
            }
            Slider(
                value: Binding(
                    get: { Double(value.wrappedValue) },
                    set: { value.wrappedValue = Int($0.rounded()) }
                ),
                in: range,
                step: 10
            )
            .tint(BWColor.white)
            .accessibilityLabel(title)
            .accessibilityValue("\(value.wrappedValue) milliseconds")
        }
    }

    private func presetIntegerBinding(_ keyPath: WritableKeyPath<FakeoutMotionPresetValues, Int>) -> Binding<Int> {
        Binding(
            get: { FakeoutMotionPresetValues(settings.preset)[keyPath: keyPath] },
            set: { newValue in
                var values = FakeoutMotionPresetValues(settings.preset)
                values[keyPath: keyPath] = newValue
                settings.preset = values.preset
                copied = false
            }
        )
    }

    private func presetDoubleBinding(_ keyPath: WritableKeyPath<FakeoutMotionPresetValues, Double>) -> Binding<Double> {
        Binding(
            get: { FakeoutMotionPresetValues(settings.preset)[keyPath: keyPath] },
            set: { newValue in
                var values = FakeoutMotionPresetValues(settings.preset)
                values[keyPath: keyPath] = newValue
                settings.preset = values.preset
                copied = false
            }
        )
    }

    private var decision: Decision {
        Decision(
            id: UUID(uuidString: "B822121B-3443-4DD6-80CC-8EA073475C8C")!,
            verdict: finalVerdict,
            category: .subjective,
            reactionId: nil,
            motionProfile: .tension,
            fakeout: true,
            responseLanguage: .en,
            usage: Usage(remainingToday: 24, state: .normal, resetsAt: .distantFuture)
        )
    }

    private func replay() {
        replayID += 1
        copied = false
    }
}

private struct FakeoutMotionPresetValues {
    var misdirectionAmount: Double
    var commitmentMilliseconds: Int
    var holdMilliseconds: Int
    var reversalMilliseconds: Int
    var preSlamPauseMilliseconds: Int

    init(_ preset: FakeoutMotionPreset) {
        misdirectionAmount = preset.misdirectionAmount
        commitmentMilliseconds = preset.commitmentMilliseconds
        holdMilliseconds = preset.holdMilliseconds
        reversalMilliseconds = preset.reversalMilliseconds
        preSlamPauseMilliseconds = preset.preSlamPauseMilliseconds
    }

    var preset: FakeoutMotionPreset {
        FakeoutMotionPreset(
            misdirectionAmount: misdirectionAmount,
            commitmentMilliseconds: commitmentMilliseconds,
            holdMilliseconds: holdMilliseconds,
            reversalMilliseconds: reversalMilliseconds,
            preSlamPauseMilliseconds: preSlamPauseMilliseconds
        )
    }
}

private struct MotionLabButtonStyle: ButtonStyle {
    var emphasized = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(BWType.button)
            .foregroundStyle(emphasized ? BWColor.black : BWColor.white)
            .padding(.horizontal, BWSpacing.medium)
            .frame(minHeight: 44)
            .background(emphasized ? BWColor.white : BWColor.black)
            .overlay(Rectangle().stroke(BWColor.white, lineWidth: 2))
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

#Preview("Fakeout Motion Lab") {
    FakeoutMotionLabView()
}

#Preview("Loading Motion Lab") {
    LoadingMotionLabView()
}
#endif
