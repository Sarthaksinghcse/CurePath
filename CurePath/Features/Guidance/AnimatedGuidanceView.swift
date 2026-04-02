//
//  AnimatedGuidanceView.swift
//  CurePath
//
//  Updated 2/19/2026
//  ✅ Extra final step: "Visit a Doctor & Take Prescribed Medication"
//  ✅ "Complete Treatment" dismisses guidance AND navigates to Home tab (via NotificationCenter)
//  ✅ "Track Progress" button also directs user to History tab
//

import SwiftUI
import AVFoundation

// MARK: - Tab navigation helper (posted to ContentView)
extension Notification.Name {
    static let switchToHomeTab    = Notification.Name("switchToHomeTab")
    static let switchToHistoryTab = Notification.Name("switchToHistoryTab")
}

// MARK: - Main Animated Guidance View
struct AnimatedGuidanceView: View {
    let image: UIImage
    let injuryType: InjuryType
    let woundRegion: CGRect?
    let onComplete: (Bool) -> Void   // true = save injury

    @State private var currentStepIndex = 0
    @State private var timeRemaining: TimeInterval = 0
    @State private var timer: Timer?
    @State private var speechSynthesizer = AVSpeechSynthesizer()
    @State private var showExitConfirmation = false
    @State private var stepProgress: CGFloat = 0
    @Environment(\.dismiss) var dismiss

    // Injury first-aid steps + our always-appended doctor step
    private var allSteps: [FirstAidAnimationStep] {
        injuryType.animatedSteps + [doctorStep]
    }

    private var doctorStep: FirstAidAnimationStep {
        FirstAidAnimationStep(
            stepNumber: injuryType.animatedSteps.count + 1,
            title: "Visit a Doctor",
            instruction: "See a healthcare professional for a proper examination. Follow any prescribed medication or dressing changes they recommend. Professional care prevents infection and helps you heal faster.",
            animationType: .visitDoctor,
            duration: 0,
            voiceText: "The final step is to visit a healthcare professional. Follow their prescribed medication and dressing instructions. Professional care prevents infection and speeds up recovery."
        )
    }

    var currentStep: FirstAidAnimationStep? {
        guard currentStepIndex < allSteps.count else { return nil }
        return allSteps[currentStepIndex]
    }
    var isLastStep: Bool { currentStepIndex >= allSteps.count - 1 }

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.06, blue: 0.10).ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Header ────────────────────────────────────────────────
                HStack {
                    Button { showExitConfirmation = true } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        ForEach(0..<allSteps.count, id: \.self) { i in
                            Circle()
                                .fill(i == currentStepIndex ? Color.blue : Color.white.opacity(0.25))
                                .frame(
                                    width:  i == currentStepIndex ? 10 : 7,
                                    height: i == currentStepIndex ? 10 : 7
                                )
                                .animation(.spring(response: 0.3), value: currentStepIndex)
                        }
                    }
                    Spacer()
                    Text("Step \(currentStepIndex + 1)/\(allSteps.count)")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.horizontal)
                .padding(.top)

                // Calm banner
                Text("Take a breath. Follow each step at your own pace.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .italic()
                    .padding(.top, 8)
                    .padding(.horizontal)

                // ── Injury photo / animation ───────────────────────────────
                ZStack {
                    // Show doctor illustration on final step, photo otherwise
                    if isLastStep {
                        DoctorIllustration()
                            .frame(maxHeight: 260)
                            .padding(.horizontal)
                    } else {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 260)
                            .cornerRadius(20)
                        if let region = woundRegion {
                            WoundBoundaryOverlay(region: region)
                        }
                        if let step = currentStep {
                            StepAnimationOverlay(animationType: step.animationType)
                                .frame(maxWidth: .infinity, maxHeight: 260)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 10)

                // ── Step progress bar ──────────────────────────────────────
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.1))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(isLastStep ? Color.green : Color.blue)
                            .frame(width: geo.size.width * stepProgress)
                            .animation(.linear(duration: 0.5), value: stepProgress)
                    }
                }
                .frame(height: 3)
                .padding(.horizontal)
                .padding(.top, 10)

                Spacer()

                // ── Instruction card ───────────────────────────────────────
                if let step = currentStep {
                    VStack(spacing: 16) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(isLastStep ? Color.green : Color.blue)
                                    .frame(width: 32, height: 32)
                                Text("\(step.stepNumber)")
                                    .font(.subheadline).fontWeight(.bold).foregroundColor(.white)
                            }
                            Text(step.title)
                                .font(.title3).fontWeight(.bold).foregroundColor(.white)
                            Spacer()
                        }

                        Text(step.instruction)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.85))
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        // Timer (non-last steps only)
                        if step.duration > 0 && timeRemaining > 0 {
                            HStack(spacing: 10) {
                                Image(systemName: "clock.fill").foregroundColor(.blue)
                                Text(formatTime(timeRemaining))
                                    .font(.title3).fontWeight(.semibold).foregroundColor(.white)
                                    .monospacedDigit()
                                Spacer()
                                CircularTimerView(progress: timeRemaining / step.duration, color: .blue)
                                    .frame(width: 36, height: 36)
                            }
                            .padding()
                            .background(Color.blue.opacity(0.15))
                            .cornerRadius(12)
                        }

                        // ── Last step: Track Progress button + Complete ──────
                        if isLastStep {
                            // Track Progress → History tab
                            Button {
                                HapticFeedback.medium()
                                stopTimer()
                                speechSynthesizer.stopSpeaking(at: .immediate)
                                onComplete(true)
                                dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    NotificationCenter.default.post(name: .switchToHistoryTab, object: nil)
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "clock.arrow.circlepath").font(.title3)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Track Wound Progress").fontWeight(.semibold)
                                        Text("Save & go to History tab").font(.caption).opacity(0.75)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.caption)
                                }
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(12)
                            }

                            // Complete Treatment → Home
                            Button(action: completeAndGoHome) {
                                HStack {
                                    Text("Complete Treatment")
                                        .fontWeight(.semibold)
                                    Image(systemName: "checkmark.circle.fill")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }

                        } else {
                            // ── Normal nav buttons ────────────────────────────
                            HStack(spacing: 12) {
                                if currentStepIndex > 0 {
                                    Button(action: previousStep) {
                                        Image(systemName: "chevron.left")
                                            .font(.headline)
                                            .frame(width: 48, height: 48)
                                            .background(Color.white.opacity(0.1))
                                            .foregroundColor(.white)
                                            .cornerRadius(12)
                                    }
                                }
                                Button(action: nextStep) {
                                    HStack {
                                        Text("Next Step").fontWeight(.semibold)
                                        Image(systemName: "chevron.right")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                            }
                        }

                        // Replay voice button
                        Button(action: speakStep) {
                            HStack(spacing: 6) {
                                Image(systemName: "speaker.wave.2.fill")
                                Text("Replay Instructions")
                            }
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(24)
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
        }
        .onAppear { setupStep() }
        .alert("Exit Guidance?", isPresented: $showExitConfirmation) {
            Button("Continue Guidance", role: .cancel) { }
            Button("Exit", role: .destructive) {
                stopTimer()
                speechSynthesizer.stopSpeaking(at: .immediate)
                onComplete(false)
                dismiss()
            }
        } message: {
            Text("Your progress won't be saved.")
        }
    }

    // MARK: - Actions

    /// Complete treatment → save injury → go Home
    private func completeAndGoHome() {
        HapticFeedback.success()
        stopTimer()
        speechSynthesizer.stopSpeaking(at: .immediate)
        onComplete(true)
        dismiss()
        // Small delay lets the sheet dismiss before switching tabs
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            NotificationCenter.default.post(name: .switchToHomeTab, object: nil)
        }
    }

    private func setupStep() {
        stopTimer()
        stepProgress = CGFloat(currentStepIndex + 1) / CGFloat(allSteps.count)
        if let step = currentStep, step.duration > 0 {
            timeRemaining = step.duration
            startTimer()
        } else {
            timeRemaining = 0
        }
        speakStep()
    }

    private func speakStep() {
        guard let step = currentStep else { return }
        speechSynthesizer.stopSpeaking(at: .immediate)
        let utterance           = AVSpeechUtterance(string: step.voiceText)
        utterance.voice         = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate          = 0.48
        utterance.pitchMultiplier = 1.05
        speechSynthesizer.speak(utterance)
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 0 { timeRemaining -= 1 }
        }
    }

    private func stopTimer() { timer?.invalidate(); timer = nil }

    private func previousStep() {
        HapticFeedback.light()
        if currentStepIndex > 0 { currentStepIndex -= 1; setupStep() }
    }

    private func nextStep() {
        HapticFeedback.light()
        currentStepIndex += 1
        setupStep()
    }

    private func formatTime(_ s: TimeInterval) -> String {
        String(format: "%d:%02d", Int(s) / 60, Int(s) % 60)
    }
}

// MARK: - Doctor Illustration (final step visual)
struct DoctorIllustration: View {
    @State private var pulse = false
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 140, height: 140)
                    .scaleEffect(pulse ? 1.08 : 1.0)
                    .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: pulse)
                VStack(spacing: 4) {
                    Image(systemName: "stethoscope")
                        .font(.system(size: 52))
                        .foregroundColor(.green)
                    Image(systemName: "cross.case.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.green.opacity(0.7))
                }
            }
            .onAppear { pulse = true }

            Text("You're almost done! 🎉")
                .font(.headline).foregroundColor(.white)
            Text("Professional care is the final piece of your recovery.")
                .font(.caption)
                .foregroundColor(.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.04))
        .cornerRadius(20)
    }
}

// MARK: - Circular Timer View
struct CircularTimerView: View {
    let progress: Double
    let color: Color
    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.2), lineWidth: 3)
            Circle().trim(from: 0, to: CGFloat(progress))
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress)
        }
    }
}

// MARK: - Step Animation Overlay
struct StepAnimationOverlay: View {
    let animationType: AnimationType
    @State private var phase: CGFloat = 0
    var body: some View {
        ZStack {
            switch animationType {
            case .handWashing:   HandWashingAnimation(phase: phase)
            case .applyPressure: PressureAnimation(phase: phase)
            case .cleanWound:    WaterFlowAnimation(phase: phase)
            case .applyBandage:  BandageAnimation(phase: phase)
            case .coolWithWater: CoolWaterAnimation(phase: phase)
            case .coverGently:   CoverAnimation(phase: phase)
            case .moveAway:      MoveAwayAnimation(phase: phase)
            case .stopAndAssess: AssessAnimation(phase: phase)
            case .applyOintment: OintmentAnimation(phase: phase)
            case .visitDoctor:   EmptyView()  // handled by DoctorIllustration
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { phase = 1 }
        }
    }
}

// MARK: - Animation Views (unchanged)

struct HandWashingAnimation: View {
    let phase: CGFloat
    var body: some View {
        VStack {
            Spacer()
            ZStack {
                ForEach(0..<6, id: \.self) { i in
                    Capsule().fill(Color.blue.opacity(0.6)).frame(width: 4, height: 20)
                        .offset(x: CGFloat(i - 3) * 12, y: -40 + phase * 60 + CGFloat(i % 2) * 15)
                        .opacity(Double(1.2 - phase))
                }
                HStack(spacing: -20) {
                    Image(systemName: "hand.raised.fill").font(.system(size: 52)).foregroundColor(.white.opacity(0.9))
                        .rotationEffect(.degrees(-15 + Double(phase) * 10)).offset(y: phase * 4)
                    Image(systemName: "hand.raised.fill").font(.system(size: 52)).foregroundColor(.white.opacity(0.9))
                        .scaleEffect(x: -1).rotationEffect(.degrees(15 - Double(phase) * 10)).offset(y: phase * -4)
                }
                ForEach(0..<4, id: \.self) { i in
                    Circle().fill(Color.white.opacity(0.5)).frame(width: CGFloat(6 + i * 2), height: CGFloat(6 + i * 2))
                        .offset(x: CGFloat(i * 15 - 20), y: -20 - phase * CGFloat(i * 8)).opacity(Double(phase))
                }
            }
            .padding(24).background(Color.black.opacity(0.55)).cornerRadius(20).padding(.bottom, 40)
        }
    }
}

struct PressureAnimation: View {
    let phase: CGFloat
    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Circle().stroke(Color.red.opacity(0.5 - Double(i) * 0.15), lineWidth: 2)
                    .frame(width: 60 + phase * CGFloat(i * 30), height: 60 + phase * CGFloat(i * 30))
                    .opacity(Double(1.2 - phase))
            }
            Image(systemName: "hand.raised.fill").font(.system(size: 72)).foregroundColor(.white.opacity(0.9))
                .offset(y: phase * 12 - 30).shadow(color: .red.opacity(0.4), radius: 8)
            RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.85)).frame(width: 60, height: 40)
                .offset(y: phase * 12 + 20)
        }
    }
}

struct WaterFlowAnimation: View {
    let phase: CGFloat
    var body: some View {
        ZStack {
            ForEach(0..<7, id: \.self) { i in
                Capsule()
                    .fill(LinearGradient(colors: [Color.blue.opacity(0.3), Color.cyan.opacity(0.8), Color.blue.opacity(0.3)],
                                        startPoint: .top, endPoint: .bottom))
                    .frame(width: 5, height: 30 + CGFloat(i % 3) * 10)
                    .offset(x: CGFloat(i - 3) * 14, y: -60 + phase * 100 + CGFloat(i % 2) * 20)
                    .opacity(Double(1.3 - phase))
            }
            Image(systemName: "drop.fill").font(.system(size: 36)).foregroundColor(.cyan)
                .offset(y: -80).scaleEffect(1.0 + phase * 0.1)
            ForEach(0..<5, id: \.self) { i in
                Circle().fill(Color.blue.opacity(0.4)).frame(width: 8, height: 8)
                    .offset(x: CGFloat(i - 2) * 18, y: 40 + (1 - phase) * 20).opacity(Double(phase))
            }
        }
    }
}

struct BandageAnimation: View {
    let phase: CGFloat
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(colors: [Color(white: 0.95), Color(white: 0.85)],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: 140 * phase, height: 44)
                .overlay(HStack(spacing: 8) {
                    ForEach(0..<5, id: \.self) { _ in
                        Rectangle().fill(Color.gray.opacity(0.3)).frame(width: 1, height: 44)
                    }
                })
                .cornerRadius(8)
            ZStack {
                Rectangle().fill(Color.red).frame(width: 4, height: 18)
                Rectangle().fill(Color.red).frame(width: 18, height: 4)
            }.opacity(Double(phase))
            Image(systemName: "hand.point.right.fill").font(.system(size: 36)).foregroundColor(.white.opacity(0.7))
                .offset(x: -80 + phase * 60, y: -30).opacity(Double(1.2 - phase))
        }
    }
}

struct CoolWaterAnimation: View {
    let phase: CGFloat
    var body: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { i in
                Capsule()
                    .fill(LinearGradient(colors: [Color.cyan.opacity(0.3), Color.blue.opacity(0.7)],
                                        startPoint: .top, endPoint: .bottom))
                    .frame(width: 6, height: 40 + CGFloat(i) * 8)
                    .offset(x: CGFloat(i - 2) * 20, y: -50 + phase * 100)
                    .opacity(Double(1.4 - phase))
            }
            Image(systemName: "snowflake").font(.system(size: 28)).foregroundColor(.cyan)
                .offset(y: -90).rotationEffect(.degrees(phase * 45))
        }
    }
}

struct CoverAnimation: View {
    let phase: CGFloat
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.75))
                .frame(width: 160 * phase, height: 110 * phase)
                .shadow(color: .blue.opacity(0.3), radius: 8)
            Image(systemName: "bandage.fill").font(.system(size: 40)).foregroundColor(.blue.opacity(0.6))
                .opacity(Double(phase))
        }
    }
}

struct MoveAwayAnimation: View {
    let phase: CGFloat
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "flame.fill").font(.system(size: 44)).foregroundColor(.orange)
                .scaleEffect(1.0 + phase * 0.2)
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: "chevron.right").foregroundColor(.white.opacity(0.5 + Double(i) * 0.2))
            }
            Image(systemName: "figure.walk").font(.system(size: 44)).foregroundColor(.green)
                .offset(x: phase * 20)
        }
        .padding(20).background(Color.black.opacity(0.55)).cornerRadius(16)
    }
}

struct AssessAnimation: View {
    let phase: CGFloat
    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Circle().stroke(Color.yellow.opacity(0.6 - Double(i) * 0.15), lineWidth: 2)
                    .frame(width: 60 + phase * CGFloat(i + 1) * 25, height: 60 + phase * CGFloat(i + 1) * 25)
                    .opacity(Double(1.1 - phase))
            }
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 44)).foregroundColor(.yellow)
                .scaleEffect(1.0 + phase * 0.1)
        }
    }
}

struct OintmentAnimation: View {
    let phase: CGFloat
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 6).fill(Color(white: 0.85)).frame(width: 30, height: 70)
                Text("Ab").font(.system(size: 9, weight: .bold)).foregroundColor(.gray)
            }
            ForEach(0..<4, id: \.self) { i in
                Capsule().fill(Color.white.opacity(0.9)).frame(width: 10, height: 14)
                    .offset(y: phase * CGFloat(i * 10 + 5)).opacity(Double(0.8 - phase * 0.2))
            }
        }
    }
}

#Preview {
    AnimatedGuidanceView(
        image: UIImage(systemName: "photo")!,
        injuryType: .cut,
        woundRegion: CGRect(x: 0.3, y: 0.3, width: 0.4, height: 0.35),
        onComplete: { _ in }
    )
}
