//
//  FirstAidGuideView.swift
//  CurePath
//
//  Updated 2/16/2026
//  Added: animated icons per step, step reveal animation, progress indicator at top
//

import SwiftUI

struct FirstAidGuideView: View {
    let injuryType: InjuryType
    @Environment(\.dismiss) var dismiss
    @State private var currentStep = 0
    @State private var completedSteps: Set<Int> = []
    @State private var headerAppeared = false
    
    var guide: FirstAidGuide {
        switch injuryType {
        case .cut:        return .cutsGuide
        case .burn:       return .burnsGuide
        case .abrasion:   return .abrasionsGuide
        case .laceration: return .lacerationGuide
        case .venomBite:  return .venomBiteGuide
        case .sprain:     return .sprainGuide
        case .nosebleed:  return .nosebleedGuide
        case .normal, .unknown: return .normalGuide
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // ── Animated Header ───────────────────────────────────
                    animatedHeader
                        .opacity(headerAppeared ? 1 : 0)
                        .offset(y: headerAppeared ? 0 : -10)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: headerAppeared)
                    
                    // ── Step progress dots ────────────────────────────────
                    stepProgressIndicator
                        .padding(.horizontal)
                    
                    // ── Steps ─────────────────────────────────────────────
                    VStack(spacing: 12) {
                        ForEach(Array(guide.steps.enumerated()), id: \.element.id) { index, step in
                            AnimatedFirstAidStepCard(
                                step: step,
                                isExpanded: currentStep == index,
                                isCompleted: completedSteps.contains(index),
                                injuryColor: injuryType.color,
                                onTap: {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        currentStep = index
                                    }
                                },
                                onComplete: {
                                    withAnimation {
                                        completedSteps.insert(index)
                                        if index < guide.steps.count - 1 {
                                            currentStep = index + 1
                                        }
                                    }
                                    HapticFeedback.light()
                                }
                            )
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .opacity
                            ))
                        }
                    }
                    .padding(.horizontal)
                    
                    // ── Warnings ──────────────────────────────────────────
                    if !guide.warnings.isEmpty {
                        warningsCard
                            .padding(.horizontal)
                    }
                    
                    // ── When to Seek Help ─────────────────────────────────
                    if !guide.whenToSeekHelp.isEmpty {
                        seekHelpCard
                            .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(.vertical)
            }
            .navigationTitle("First-Aid Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear { withAnimation { headerAppeared = true }; OrientationLockHelper.lockPortrait() }
    }
    
    // MARK: - Animated Header
    private var animatedHeader: some View {
        HStack(spacing: 16) {
            AnimatedGuideIcon(icon: injuryType.icon, color: injuryType.color)
            VStack(alignment: .leading, spacing: 4) {
                Text(guide.title).font(.title2).fontWeight(.bold)
                Text(guide.subtitle).font(.subheadline).foregroundColor(.secondary)
            }
            Spacer()
            // Completion badge
            if completedSteps.count == guide.steps.count && !guide.steps.isEmpty {
                Label("Done!", systemImage: "checkmark.seal.fill")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundColor(.green)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Step progress dots
    private var stepProgressIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<guide.steps.count, id: \.self) { i in
                let isDone = completedSteps.contains(i)
                let isCurrent = currentStep == i
                RoundedRectangle(cornerRadius: 3)
                    .fill(isDone ? injuryType.color
                          : isCurrent ? injuryType.color.opacity(0.5)
                          : Color.gray.opacity(0.2))
                    .frame(maxWidth: .infinity)
                    .frame(height: 4)
                    .animation(.spring(response: 0.3), value: isDone || isCurrent)
            }
        }
    }
    
    // MARK: - Warnings
    private var warningsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            // Header
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                
                Text("Important Warnings")
                    .font(.headline)
            }
            
            // List
            ForEach(guide.warnings, id: \.self) { warning in
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 6, height: 6)
                        .padding(.top, 6)
                    
                    Text(warning)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    Spacer(minLength: 0) // helps expand row
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading) // ✅ full width
        .padding(16)
        .background(Color.orange.opacity(0.08))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.orange.opacity(0.25), lineWidth: 1)
        )
    }
    
    private var seekHelpCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            // Header
            HStack(spacing: 8) {
                Image(systemName: "phone.circle.fill")
                    .foregroundColor(.red)
                
                Text("Seek Medical Help If:")
                    .font(.headline)
            }
            
            // List
            ForEach(guide.whenToSeekHelp, id: \.self) { condition in
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 6, height: 6)
                        .padding(.top, 6)
                    
                    Text(condition)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    Spacer(minLength: 0) // expands row
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading) // ✅ full width
        .padding(16)
        .background(Color.red.opacity(0.07))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.red.opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - Animated Guide Icon (pulses on appear)
struct AnimatedGuideIcon: View {
    let icon: String
    let color: Color
    @State private var pulsing = false
    @State private var rotating = false

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: 64, height: 64)
                .scaleEffect(pulsing ? 1.08 : 1.0)
                .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: pulsing)
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(color)
                .rotationEffect(.degrees(rotating ? 5 : -5))
                .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: rotating)
        }
        .onAppear { pulsing = true; rotating = true }
    }
}

// MARK: - Animated Step Card
struct AnimatedFirstAidStepCard: View {
    let step: FirstAidStep
    let isExpanded: Bool
    let isCompleted: Bool
    let injuryColor: Color
    let onTap: () -> Void
    let onComplete: () -> Void

    @State private var iconAnimating = false
    @State private var timerProgress: Double = 1.0
    @State private var timer: Timer?
    @State private var timeRemaining: TimeInterval = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Header row ────────────────────────────────────────────
            Button(action: onTap) {
                HStack(spacing: 14) {
                    // Step number / completion indicator
                    ZStack {
                        Circle()
                            .fill(isCompleted ? injuryColor
                                  : isExpanded ? injuryColor.opacity(0.15)
                                  : Color.gray.opacity(0.1))
                            .frame(width: 36, height: 36)
                            .animation(.spring(response: 0.35), value: isCompleted || isExpanded)

                        if isCompleted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            Text("\(step.stepNumber)")
                                .font(.subheadline).fontWeight(.semibold)
                                .foregroundColor(isExpanded ? injuryColor : .secondary)
                        }
                    }

                    // Animated icon
                    if let icon = step.icon {
                        Image(systemName: icon)
                            .font(.system(size: 18))
                            .foregroundColor(isExpanded ? injuryColor : .secondary)
                            .scaleEffect(iconAnimating && isExpanded ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                                       value: iconAnimating && isExpanded)
                    }

                    Text(step.title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .animation(.spring(response: 0.3), value: isExpanded)
                }
                .padding(16)
            }
            .buttonStyle(PlainButtonStyle())

            // ── Expanded content ──────────────────────────────────────
            if isExpanded {
                VStack(alignment: .leading, spacing: 14) {
                    Divider().padding(.horizontal, 16)

                    // ── Step illustration image ────────────────────────
                    HStack {
                        Spacer()
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(injuryColor.opacity(0.08))
                                .frame(width: 110, height: 110)
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(injuryColor.opacity(0.18), lineWidth: 1.5)
                                .frame(width: 110, height: 110)
                            Image(systemName: step.illustrationIcon)
                                .font(.system(size: 52, weight: .light))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [injuryColor, injuryColor.opacity(0.6)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .scaleEffect(iconAnimating ? 1.06 : 0.97)
                                .animation(
                                    .easeInOut(duration: 1.1).repeatForever(autoreverses: true),
                                    value: iconAnimating
                                )
                        }
                        Spacer()
                    }
                    .padding(.top, 4)

                    // Description with animated reveal
                    Text(step.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineSpacing(3)
                        .padding(.horizontal, 16)
                        .transition(.move(edge: .top).combined(with: .opacity))

                    // Timer if applicable
                    if let duration = step.duration, duration > 0 {
                        timerView(duration: duration)
                            .padding(.horizontal, 16)
                    }

                    // Mark done button
                    Button(action: onComplete) {
                        HStack(spacing: 8) {
                            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                            Text(isCompleted ? "Step Completed ✓" : "Mark as Done")
                        }
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundColor(isCompleted ? .green : injuryColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isCompleted ? Color.green.opacity(0.1) : injuryColor.opacity(0.1))
                        .cornerRadius(10)
                    }
                    .disabled(isCompleted)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
                .shadow(color: isExpanded ? injuryColor.opacity(0.12) : Color.black.opacity(0.04),
                        radius: isExpanded ? 10 : 4, x: 0, y: isExpanded ? 4 : 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isExpanded ? injuryColor.opacity(0.3) : Color.clear, lineWidth: 1.5)
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isExpanded)
        .onChange(of: isExpanded) { _, expanded in
            if expanded {
                iconAnimating = true
                if let duration = step.duration, duration > 0 {
                    timeRemaining = duration
                    timerProgress = 1.0
                }
            } else {
                iconAnimating = false
                timer?.invalidate(); timer = nil
            }
        }
    }

    // MARK: - Timer view
    private func timerView(duration: TimeInterval) -> some View {
        HStack(spacing: 12) {
            // Circular timer ring
            ZStack {
                Circle().stroke(Color.gray.opacity(0.2), lineWidth: 3).frame(width: 36, height: 36)
                Circle()
                    .trim(from: 0, to: timerProgress)
                    .stroke(injuryColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 36, height: 36)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: timerProgress)
                Image(systemName: "clock.fill")
                    .font(.system(size: 14)).foregroundColor(injuryColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(formatTime(timeRemaining))
                    .font(.headline).fontWeight(.bold).foregroundColor(injuryColor).monospacedDigit()
                Text("Hold for \(formatTime(duration))")
                    .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Button(timeRemaining == duration ? "Start" : "Reset") {
                startTimer(duration: duration)
            }
            .font(.subheadline).fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 14).padding(.vertical, 7)
            .background(injuryColor)
            .cornerRadius(8)
        }
        .padding(12)
        .background(injuryColor.opacity(0.07))
        .cornerRadius(10)
    }

    private func startTimer(duration: TimeInterval) {
        timer?.invalidate()
        timeRemaining = duration
        timerProgress = 1.0
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { t in
            if timeRemaining > 0 {
                timeRemaining -= 1
                timerProgress = timeRemaining / duration
            } else {
                t.invalidate()
                HapticFeedback.success()
            }
        }
    }

    private func formatTime(_ s: TimeInterval) -> String {
        let m = Int(s) / 60; let sec = Int(s) % 60
        return m > 0 ? "\(m):\(String(format:"%02d",sec))" : "\(Int(s))s"
    }
}

// Fallback static extensions kept for reference (normalGuide etc already in Models.swift)
#Preview {
    FirstAidGuideView(injuryType: .cut)
}
