# Black & White

A native SwiftUI app for yes-or-no questions. I built it with Codex to explore how far I could strip down a decision-making interface, then used motion and haptics to give the answer some weight.

This is the standalone iOS demo. The app uses local sample responses, so you can run the whole flow without an account, API key, or network connection. It does not run a live AI model or save your questions between launches.

## Run the demo

1. Open [ios/BlackAndWhite.xcodeproj](ios/BlackAndWhite.xcodeproj) in Xcode 26.6.
2. Select the **BlackAndWhite** scheme and an iPhone simulator, then press **Run** (⌘R).
3. Try **Should I drink more water?** for Yes, **Should I check my email before bed?** for No, or **Where should I travel?** for the unsupported-question state.

The code includes the SwiftUI interface, decision-flow state machine, verdict animations, and a local decision service. The production backend and deployment configuration are not included.
