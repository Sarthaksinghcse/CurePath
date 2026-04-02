import SwiftUI
import PhotosUI

// MARK: - Entry point
struct DailyCheckInView: View {
    let injury: InjuryRecord

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var dataManager = InjuryDataManager.shared

    @State private var showCamera     = false
    @State private var pickerItem:    PhotosPickerItem?
    @State private var capturedImage: UIImage?

    @State private var isAnalysing    = false
    @State private var mlRejected     = false
    @State private var mlRejectMsg    = ""
    @State private var newCheckIn:    DailyCheckIn?
    @State private var showResult     = false

    @State private var selectedDay:   Int

    init(injury: InjuryRecord) {
        self.injury = injury
        _selectedDay = State(initialValue: injury.currentDay + 1)
    }

    private var canSave: Bool { newCheckIn != nil && !mlRejected }

    // Previous check-in = the most recent one (for trend comparison)
    private var previousCheckIn: DailyCheckIn? { injury.latestCheckIn }

    var body: some View {
        NavigationView {
            Group {
                if isAnalysing {
                    analysingView
                } else if mlRejected {
                    mlRejectedView
                } else if showResult, let ci = newCheckIn {
                    CheckInResultView(
                        injury:        injury,
                        newCheckIn:    ci,
                        capturedImage: capturedImage,
                        selectedDay:   selectedDay,
                        canSave:       canSave,
                        onSave:        { saveAndDismiss(ci) },
                        onRetake:      resetAll
                    )
                } else {
                    capturePrompt
                }
            }
            .navigationTitle("Day \(selectedDay) Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.disabled(isAnalysing)
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPickerView(isPresented: $showCamera, selectedImage: $capturedImage).ignoresSafeArea()
        }
        .onChange(of: capturedImage) { _, img in if let img { runAnalysis(img) } }
        .onChange(of: pickerItem) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self),
                   let img  = UIImage(data: data) {
                    await MainActor.run { capturedImage = img; runAnalysis(img) }
                }
            }
        }
    }

    // MARK: - Capture prompt
    private var capturePrompt: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer().frame(height: 4)

                // ── Position reminder banner (always shown, prominent) ──────
                positionReminderBanner

                // ── Previous photo reference ──────────────────────────────
                if let prev = previousCheckIn,
                   let img  = WoundProgressService.loadImage(filename: prev.imagePath) {
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.caption).foregroundColor(.blue)
                            Text("Your last photo  ·  \(prev.shortDateTime)")
                                .font(.caption).fontWeight(.semibold).foregroundColor(.blue)
                        }

                        ZStack(alignment: .bottomLeading) {
                            Image(uiImage: img).resizable().scaledToFit()
                                .frame(height: 200).cornerRadius(14)
                                .overlay(RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 1.5))

                            // Overlay label
                            Text("Match this angle & distance ↑")
                                .font(.caption2).fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color.blue.opacity(0.85))
                                .cornerRadius(6)
                                .padding(8)
                        }
                    }
                    .padding(.horizontal)
                }

                // ── Day picker ────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 8) {
                    Text("Which day is this photo for?")
                        .font(.subheadline).fontWeight(.semibold).padding(.horizontal)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(1...max(injury.totalDays, injury.currentDay + 3), id: \.self) { day in
                                Button { selectedDay = day; HapticFeedback.light() } label: {
                                    Text("Day \(day)")
                                        .font(.subheadline)
                                        .fontWeight(selectedDay == day ? .bold : .regular)
                                        .foregroundColor(selectedDay == day ? .white : .primary)
                                        .padding(.horizontal, 16).padding(.vertical, 9)
                                        .background(selectedDay == day ? injury.type.color : Color(.systemGray5))
                                        .cornerRadius(22)
                                }
                            }
                        }.padding(.horizontal)
                    }.frame(height: 46)
                }

                // ── Capture buttons ───────────────────────────────────────
                VStack(spacing: 12) {
                    Button { HapticFeedback.medium(); showCamera = true } label: {
                        Label("Take Photo", systemImage: "camera.fill")
                            .font(.headline).fontWeight(.semibold)
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                            .background(LinearGradient(colors: [.blue, Color(red:0.12,green:0.32,blue:0.78)],
                                                       startPoint: .leading, endPoint: .trailing))
                            .foregroundColor(.white).cornerRadius(15)
                            .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label("Choose from Library", systemImage: "photo.stack.fill")
                            .font(.headline).fontWeight(.semibold)
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                            .background(Color(.systemGray6))
                            .foregroundColor(.blue).cornerRadius(15)
                    }
                }.padding(.horizontal)

                // ── Tip badges ────────────────────────────────────────────
                HStack(spacing: 8) {
                    tipBadge(icon: "camera.macro",       text: "15–30 cm")
                    tipBadge(icon: "light.max",          text: "Good light")
                    tipBadge(icon: "arrow.2.squarepath", text: "Same angle")
                    tipBadge(icon: "timer",              text: "Hold steady")
                }.padding(.horizontal)

                Spacer().frame(height: 16)
            }
        }
    }

    // MARK: - Position reminder banner
    private var positionReminderBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(Color.orange.opacity(0.15)).frame(width: 38, height: 38)
                    Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                        .font(.system(size: 17)).foregroundColor(.orange)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Photo Position Is Important")
                        .font(.subheadline).fontWeight(.bold).foregroundColor(.orange)
                    Text("For accurate comparison, match your previous photo exactly")
                        .font(.caption).foregroundColor(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                positionTip(icon: "arrow.up.and.down.and.arrow.left.and.right",
                            text: "Same distance — keep the wound the same size in frame")
                positionTip(icon: "rotate.3d",
                            text: "Same angle — avoid tilting or rotating the camera")
                positionTip(icon: "sun.max.fill",
                            text: "Similar lighting — use the same light source if possible")
                positionTip(icon: "exclamationmark.triangle.fill",
                            text: "Different angle = inaccurate comparison results",
                            highlight: true)
            }
        }
        .padding(14)
        .background(Color.orange.opacity(0.06))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.orange.opacity(0.25), lineWidth: 1))
        .padding(.horizontal)
    }

    private func positionTip(icon: String, text: String, highlight: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(highlight ? .orange : .secondary)
                .frame(width: 16)
                .padding(.top, 1)
            Text(text)
                .font(.caption)
                .foregroundColor(highlight ? .orange : .secondary)
                .fontWeight(highlight ? .semibold : .regular)
        }
    }

    private func tipBadge(icon: String, text: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.headline).foregroundColor(.blue)
            Text(text).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .background(Color(.systemGray6)).cornerRadius(10)
    }

    // MARK: - Analysing view
    private var analysingView: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle().stroke(Color.blue.opacity(0.1), lineWidth: 2).frame(width: 130, height: 130)
                ScanningRingView()
            }
            VStack(spacing: 8) {
                Text("Analysing wound…").font(.title3).fontWeight(.bold)
                Text("Comparing size, colour and shape with previous photo")
                    .font(.subheadline).foregroundColor(.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal, 32)
            }
            Spacer()
        }
    }

    // MARK: - ML rejected view
    private var mlRejectedView: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 20)
                ZStack {
                    Circle().fill(Color.orange.opacity(0.1)).frame(width: 120, height: 120)
                    Image(systemName: "questionmark.circle.fill").font(.system(size: 52)).foregroundColor(.orange)
                }
                VStack(spacing: 8) {
                    Text("Photo Not Usable").font(.title2).fontWeight(.bold)
                    Text(mlRejectMsg)
                        .font(.subheadline).foregroundColor(.secondary)
                        .multilineTextAlignment(.center).padding(.horizontal, 32)
                }
                if let img = capturedImage {
                    Image(uiImage: img).resizable().scaledToFit()
                        .frame(height: 200).cornerRadius(14).padding(.horizontal)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.orange.opacity(0.4), lineWidth: 2))
                }
                VStack(spacing: 12) {
                    Button(action: resetAll) {
                        Label("Retake Photo", systemImage: "camera.rotate.fill")
                            .font(.headline).fontWeight(.semibold)
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                            .background(Color.orange).foregroundColor(.white).cornerRadius(15)
                    }
                    Button { dismiss() } label: {
                        Text("Cancel").font(.subheadline).foregroundColor(.secondary)
                    }
                }.padding(.horizontal)
            }
        }
    }

    // MARK: - Analysis logic
    private func runAnalysis(_ image: UIImage) {
        isAnalysing = true
        mlRejected  = false

        // Always pass the immediately previous check-in for trend comparison
        WoundProgressService.analyse(
            image:      image,
            injuryType: injury.type,
            previous:   previousCheckIn   // latest check-in = immediately previous
        ) { ci in
            self.isAnalysing = false
            guard let ci else {
                self.mlRejected   = true
                self.mlRejectMsg  = "Could not analyse the photo. Try again with better lighting."
                self.capturedImage = image
                self.showResult   = true
                HapticFeedback.warning()
                return
            }
            // If wound score is near zero AND there was a previous check-in with a real wound,
            // this means the wound has healed — treat it as healing confirmation, not an error.
            if ci.woundScore < 0.02 {
                if (self.previousCheckIn?.woundScore ?? 0) > 0.05 {
                    // Wound was present before, now it's gone — healing confirmed.
                    // Fall through to show result normally (trend will be .healing).
                } else {
                    // No prior wound either — non-wound photo submitted by mistake.
                    self.mlRejected   = true
                    self.mlRejectMsg  = "No wound detected. Make sure the wound is clearly visible and centred, then retake."
                    self.capturedImage = image
                    self.showResult   = true
                    HapticFeedback.warning()
                    return
                }
            }
            self.newCheckIn = ci
            self.showResult = true
            HapticFeedback.medium()
        }
    }

    private func saveAndDismiss(_ ci: DailyCheckIn) {
        dataManager.addCheckIn(ci, to: injury.id)
        HapticFeedback.success()
        dismiss()
    }

    private func resetAll() {
        capturedImage = nil; pickerItem = nil; newCheckIn = nil
        showResult = false; isAnalysing = false; mlRejected = false; mlRejectMsg = ""
    }
}

// MARK: - Result View
struct CheckInResultView: View {
    let injury:        InjuryRecord
    let newCheckIn:    DailyCheckIn
    let capturedImage: UIImage?
    let selectedDay:   Int
    let canSave:       Bool
    let onSave:        () -> Void
    let onRetake:      () -> Void

    @State private var appeared = false

    // The immediately previous check-in (for "vs previous" card)
    private var previousCI: DailyCheckIn? { injury.latestCheckIn }
    // The very first check-in (baseline, for "vs Day 1" card)
    private var baselineCI:  DailyCheckIn? { injury.checkIns.first }

    private var previousImage: UIImage? {
        previousCI.flatMap { WoundProgressService.loadImage(filename: $0.imagePath) }
    }
    private var baselineImage: UIImage? {
        baselineCI.flatMap { WoundProgressService.loadImage(filename: $0.imagePath) }
    }

    // Overall improvement = baseline score vs new score (labelled clearly, separate from trend)
    private var overallImprovementPct: Double? {
        guard let d1 = baselineCI, d1.woundScore > 0.01 else { return nil }
        // Only show if baseline and current aren't the same check-in
        guard baselineCI?.id != previousCI?.id else { return nil }
        return (d1.woundScore - newCheckIn.woundScore) / d1.woundScore * 100
    }

    private var wouldTriggerDoctor: Bool {
        WoundProgressService.updateConsecutiveStableDays(
            checkIns: injury.checkIns + [newCheckIn]
        ) >= 3
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {

                // ── Trend badge (vs previous only) ────────────────────────
                trendBadge
                    .opacity(appeared ? 1 : 0).scaleEffect(appeared ? 1 : 0.9)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: appeared)

                // ── Position reminder (compact, on result screen too) ──────
                positionNote
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeOut.delay(0.05), value: appeared)

                // ── Today vs Previous (trend comparison) ──────────────────
                compCard(
                    leftImage:  previousImage,
                    leftLabel:  previousCI.map { "Previous  ·  \($0.shortDateTime)" } ?? "Previous",
                    leftScore:  previousCI?.woundScore,
                    rightImage: capturedImage,
                    rightLabel: "Day \(selectedDay)  ·  Now",
                    rightScore: newCheckIn.woundScore,
                    badge:      "Trend vs Previous",
                    badgeColor: newCheckIn.trend.color
                )
                .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 12)
                .animation(.spring(response: 0.5).delay(0.1), value: appeared)

                // ── Today vs Day 1 (overall improvement — only when 2+ prior check-ins) ──
                if let pct = overallImprovementPct, let bImg = baselineImage {
                    overallImprovementCard(pct: pct, baselineImage: bImg)
                        .opacity(appeared ? 1 : 0).offset(y: appeared ? 0 : 12)
                        .animation(.spring(response: 0.5).delay(0.15), value: appeared)
                }

                if wouldTriggerDoctor {
                    doctorCard
                        .opacity(appeared ? 1 : 0)
                        .animation(.spring(response: 0.5).delay(0.2), value: appeared)
                }

                // ── Action buttons ────────────────────────────────────────
                VStack(spacing: 12) {
                    Button(action: onSave) {
                        Label("Save Progress", systemImage: "checkmark.circle.fill")
                            .font(.headline).fontWeight(.semibold)
                            .frame(maxWidth: .infinity).padding()
                            .background(canSave ? Color.blue : Color(.systemGray4))
                            .foregroundColor(.white).cornerRadius(15)
                            .shadow(color: canSave ? Color.blue.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
                    }
                    .disabled(!canSave)

                    Button(action: onRetake) {
                        Label("Retake Photo", systemImage: "camera.rotate.fill")
                            .font(.subheadline).fontWeight(.medium)
                            .frame(maxWidth: .infinity).padding()
                            .background(Color(.systemGray6))
                            .foregroundColor(.blue).cornerRadius(15)
                    }
                }
                .padding(.horizontal).padding(.bottom, 32)
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.5).delay(0.25), value: appeared)
            }
            .padding(.top, 16)
        }
        .onAppear { withAnimation { appeared = true } }
    }

    // MARK: - Trend badge (vs previous only)
    private var trendBadge: some View {
        // Special case: wound score near zero = healed skin detected
        let isHealed = newCheckIn.woundScore < 0.02 && newCheckIn.trend == .healing

        return HStack(spacing: 12) {
            ZStack {
                Circle().fill((isHealed ? Color.green : newCheckIn.trend.color).opacity(0.15)).frame(width: 52, height: 52)
                Image(systemName: isHealed ? "checkmark.seal.fill" : newCheckIn.trend.icon)
                    .font(.system(size: 24))
                    .foregroundColor(isHealed ? .green : newCheckIn.trend.color)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(isHealed ? "Healed! 🎉" : newCheckIn.trend.label)
                        .font(.title3).fontWeight(.bold)
                        .foregroundColor(isHealed ? .green : newCheckIn.trend.color)
                    if !isHealed {
                        Text("vs previous photo")
                            .font(.caption2).foregroundColor(.secondary)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color(.systemGray5)).cornerRadius(4)
                    }
                }
                if isHealed {
                    Text("No wound detected — skin looks healthy now!")
                        .font(.subheadline).foregroundColor(.secondary)
                } else if let d = newCheckIn.deltaScore {
                    Text("Wound score \(d < 0 ? "reduced" : "increased") by \(String(format:"%.1f", Swift.abs(d)*100))% since last photo")
                        .font(.subheadline).foregroundColor(.secondary)
                } else {
                    Text("Baseline photo — Day \(selectedDay)")
                        .font(.subheadline).foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding()
        .background((isHealed ? Color.green : newCheckIn.trend.color).opacity(0.07)).cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke((isHealed ? Color.green : newCheckIn.trend.color).opacity(0.2), lineWidth: 1))
        .padding(.horizontal)
    }

    // MARK: - Position note (compact)
    private var positionNote: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill").foregroundColor(.blue).font(.caption)
            Text("Comparison accuracy depends on taking photos from the same angle and distance each time.")
                .font(.caption).foregroundColor(.secondary)
        }
        .padding(10)
        .background(Color.blue.opacity(0.05))
        .cornerRadius(10)
        .padding(.horizontal)
    }

    // MARK: - Comparison card (trend: vs previous)
    private func compCard(
        leftImage: UIImage?,  leftLabel: String,  leftScore: Double?,
        rightImage: UIImage?, rightLabel: String, rightScore: Double,
        badge: String, badgeColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Badge clearly labels what this comparison is
            HStack(spacing: 6) {
                Image(systemName: "arrow.left.arrow.right.circle.fill")
                    .font(.caption).foregroundColor(badgeColor)
                Text(badge).font(.caption).fontWeight(.semibold).foregroundColor(badgeColor)
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(badgeColor.opacity(0.10)).cornerRadius(6)

            HStack(spacing: 8) {
                photoSide(image: leftImage,  label: leftLabel,  score: leftScore,  accent: false)
                Image(systemName: "arrow.right").font(.title2)
                    .foregroundColor(.blue.opacity(0.35)).frame(width: 28)
                photoSide(image: rightImage, label: rightLabel, score: rightScore, accent: true)
            }
        }
        .padding()
        .background(Color(.systemBackground)).cornerRadius(16)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
        .padding(.horizontal)
    }

    // MARK: - Overall improvement card (vs Day 1 — separate, clearly labelled)
    private func overallImprovementCard(pct: Double, baselineImage: UIImage) -> some View {
        let col: Color = pct > 0 ? .green : pct < -5 ? .orange : .blue
        let icon = pct > 0 ? "arrow.down.circle.fill" : pct < -5 ? "arrow.up.circle.fill" : "equal.circle.fill"

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "chart.line.downtrend.xyaxis.circle.fill")
                    .font(.caption).foregroundColor(col)
                Text("Overall Progress Since Day 1")
                    .font(.caption).fontWeight(.semibold).foregroundColor(col)
                Text("(separate from trend above)")
                    .font(.caption2).foregroundColor(.secondary)
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(col.opacity(0.08)).cornerRadius(6)

            HStack(spacing: 8) {
                photoSide(image: baselineImage, label: "Day 1  ·  Baseline",
                          score: baselineCI?.woundScore, accent: false)
                Image(systemName: "arrow.right").font(.title2)
                    .foregroundColor(col.opacity(0.4)).frame(width: 28)
                photoSide(image: capturedImage, label: "Day \(selectedDay)  ·  Now",
                          score: newCheckIn.woundScore, accent: true)
            }

            HStack(spacing: 10) {
                Image(systemName: icon).font(.title3).foregroundColor(col)
                Text(pct > 0
                     ? "Wound has reduced ~\(String(format:"%.0f",pct))% since Day 1"
                     : pct < -5
                         ? "Wound appears ~\(String(format:"%.0f",abs(pct)))% larger than Day 1"
                         : "Similar size to Day 1 baseline")
                    .font(.subheadline).fontWeight(.semibold).foregroundColor(col)
            }
            .padding(10).background(col.opacity(0.07)).cornerRadius(10)
        }
        .padding()
        .background(Color(.systemBackground)).cornerRadius(16)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
        .padding(.horizontal)
    }

    // MARK: - Photo side
    private func photoSide(image: UIImage?, label: String, score: Double?, accent: Bool) -> some View {
        VStack(spacing: 5) {
            Group {
                if let img = image {
                    Image(uiImage: img).resizable().scaledToFill()
                        .frame(maxWidth: .infinity).frame(height: 130).clipped().cornerRadius(10)
                } else {
                    RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray5))
                        .frame(maxWidth: .infinity, maxHeight: 130)
                        .overlay(Image(systemName: "photo").font(.largeTitle).foregroundColor(.secondary))
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(accent ? newCheckIn.trend.color.opacity(0.5) : Color.clear, lineWidth: 2))
            Text(label).font(.caption).fontWeight(accent ? .semibold : .regular)
                .foregroundColor(accent ? .primary : .secondary).lineLimit(1).minimumScaleFactor(0.7)
            if let s = score {
                let pct = Int(s * 100)
                let col: Color = pct < 30 ? .green : pct < 60 ? .orange : .red
                Text("Score: \(pct)%").font(.caption2).fontWeight(.bold).foregroundColor(col)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(col.opacity(0.1)).cornerRadius(4)
            }
        }.frame(maxWidth: .infinity)
    }

    // MARK: - Doctor card
    private var doctorCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(Color.red.opacity(0.12)).frame(width: 44, height: 44)
                    Image(systemName: "stethoscope").font(.title3).foregroundColor(.red)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Consider Seeing a Doctor").font(.headline)
                    Text("3+ consecutive days without healing progress").font(.caption).foregroundColor(.secondary)
                }
            }
            Text("No clear healing has been detected in several check-ins. A healthcare professional can check for signs of infection and advise on next steps.")
                .font(.subheadline).foregroundColor(.secondary).lineSpacing(3)
        }
        .padding().background(Color.red.opacity(0.06)).cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.red.opacity(0.2), lineWidth: 1))
        .padding(.horizontal)
    }
}
