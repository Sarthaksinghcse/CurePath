import SwiftUI

// MARK: - Main History Tab

struct HistoryView: View {
    @ObservedObject private var dataManager = InjuryDataManager.shared
    @State private var selectedInjury: InjuryRecord?
    @State private var selectedForCheckIn: InjuryRecord?

    var activeInjuries: [InjuryRecord]  { dataManager.injuries.filter { $0.isActive } }
    var healedInjuries: [InjuryRecord]  { dataManager.injuries.filter { !$0.isActive } }

    var body: some View {
        NavigationView {
            Group {
                if dataManager.injuries.isEmpty {
                    emptyState
                } else {
                    List {
                        if !activeInjuries.isEmpty {
                            Section {
                                ForEach(activeInjuries) { injury in
                                    InjuryRow(injury: injury)
                                        .contentShape(Rectangle())
                                        .onTapGesture { selectedInjury = injury }
                                }
                                .onDelete { offsets in
                                    deleteFrom(activeInjuries, offsets: offsets)
                                }
                            } header: {
                                Label("Active", systemImage: "waveform.path.ecg")
                                    .foregroundColor(.primary)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .textCase(nil)
                            }
                        }

                        if !healedInjuries.isEmpty {
                            Section {
                                ForEach(healedInjuries) { injury in
                                    InjuryRow(injury: injury)
                                        .contentShape(Rectangle())
                                        .onTapGesture { selectedInjury = injury }
                                }
                                .onDelete { offsets in
                                    deleteFrom(healedInjuries, offsets: offsets)
                                }
                            } header: {
                                Label("Healed", systemImage: "checkmark.seal.fill")
                                    .foregroundColor(.primary)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .textCase(nil)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Recovery History")
            .toolbar {
                if !dataManager.injuries.isEmpty {
                    EditButton()
                }
            }
        }
        .sheet(item: $selectedInjury) { injury in
            InjuryDetailSheet(
                injury: injury,
                onAddPhoto: { selectedInjury = nil; selectedForCheckIn = injury }
            )
        }
        .sheet(item: $selectedForCheckIn) { injury in
            DailyCheckInView(injury: injury)
        }
    }

    private func deleteFrom(_ list: [InjuryRecord], offsets: IndexSet) {
        HapticFeedback.warning()
        offsets.map { list[$0] }.forEach { dataManager.deleteInjury($0) }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 56))
                .foregroundColor(.secondary.opacity(0.4))
            Text("No Recovery Records")
                .font(.title3).fontWeight(.semibold)
            Text("Scan an injury from the Home tab to start tracking your recovery.")
                .font(.subheadline).foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
            Spacer()
        }
    }
}

// MARK: - Injury List Row

struct InjuryRow: View {
    let injury: InjuryRecord

    private var latestTrend: WoundTrend { injury.latestCheckIn?.trend ?? .baseline }
    private var showDoctorAlert: Bool {
        let daysSince = Calendar.current.dateComponents([.day], from: injury.date, to: Date()).day ?? 0
        let healed = injury.checkIns.filter { $0.trend == .healing }.count
        return injury.needsDoctorSuggestion || (daysSince >= 4 && healed == 0 && injury.checkIns.count >= 2)
    }

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(injury.type.color.opacity(0.12))
                    .frame(width: 42, height: 42)
                Image(systemName: injury.type.icon)
                    .font(.system(size: 18))
                    .foregroundColor(injury.type.color)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(injury.title)
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    if showDoctorAlert {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                HStack(spacing: 4) {
                    Text(injury.formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("·")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Day \(injury.currentDay)/\(injury.totalDays)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if latestTrend != .baseline {
                        Text("·")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Image(systemName: latestTrend.icon)
                            .font(.system(size: 9))
                            .foregroundColor(latestTrend.color)
                        Text(latestTrend.label)
                            .font(.caption)
                            .foregroundColor(latestTrend.color)
                    }
                }
            }

            Spacer()

            // Status pill
            Text(injury.isActive ? "Active" : "Healed")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(injury.isActive ? .green : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background((injury.isActive ? Color.green : Color.secondary).opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Detail Sheet

struct InjuryDetailSheet: View {
    let injury: InjuryRecord
    let onAddPhoto: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var comparisonResult: WoundComparisonResult?
    @State private var isRunningComparison = false
    @State private var comparisonRan = false
    @State private var showDoctorAlert = false

    private var latestTrend: WoundTrend { injury.latestCheckIn?.trend ?? .baseline }

    var body: some View {
        NavigationView {
            List {

                // MARK: Hero image section
                if let img = WoundProgressService.loadImage(filename: injury.imagePath) {
                    Section {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .clipped()
                            .listRowInsets(EdgeInsets())
                    }
                }

                // MARK: Doctor alert (when needed)
                if shouldShowDoctorAlert {
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: comparisonResult?.isInfectionRisk == true ? "microbe.fill" : "stethoscope")
                                .font(.title3)
                                .foregroundColor(.red)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(comparisonResult?.isInfectionRisk == true
                                     ? "Possible Infection"
                                     : "Consider Seeing a Doctor")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.red)
                                Text("No healing detected in 4+ days. Book an appointment.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color.red.opacity(0.07))
                }

                // MARK: Recovery progress section
                Section("Recovery Progress") {
                    // Day counter
                    HStack {
                        Label("Day", systemImage: "calendar")
                            .foregroundColor(.primary)
                        Spacer()
                        Text("\(injury.currentDay) of \(injury.totalDays)")
                            .foregroundColor(.secondary)
                            .fontWeight(.medium)
                    }

                    // Progress bar
                    VStack(alignment: .leading, spacing: 8) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(.systemGray5))
                                    .frame(height: 8)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(LinearGradient(
                                        colors: [injury.type.color.opacity(0.7), injury.type.color],
                                        startPoint: .leading, endPoint: .trailing))
                                    .frame(width: geo.size.width * injury.progress, height: 8)
                                    .animation(.spring(response: 0.6), value: injury.progress)
                            }
                        }
                        .frame(height: 8)
                        HStack {
                            Text(injury.formattedDate)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(injury.isActive ? "In progress" : "Fully healed")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(injury.isActive ? injury.type.color : .green)
                        }
                    }
                    .padding(.vertical, 2)

                    // Latest trend
                    if latestTrend != .baseline {
                        HStack {
                            Label("Latest Trend", systemImage: latestTrend.icon)
                                .foregroundColor(.primary)
                            Spacer()
                            Text(latestTrend.label)
                                .foregroundColor(latestTrend.color)
                                .fontWeight(.medium)
                        }
                    }

                    // Encouragement
                    HStack(spacing: 8) {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundColor(injury.type.color)
                        Text(EncouragementSystem.message(for: injury))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // MARK: Check-in stats section
                if injury.checkIns.count >= 2 {
                    Section("Wound Analysis") {
                        let cis   = injury.checkIns
                        let first = cis.first!
                        let last  = cis.last!
                        let oc    = first.woundScore > 0.01
                            ? (first.woundScore - last.woundScore) / first.woundScore * 100 : 0
                        let hc = cis.dropFirst().filter { $0.trend == .healing   }.count
                        let sc = cis.dropFirst().filter { $0.trend == .stable    }.count
                        let wc = cis.dropFirst().filter { $0.trend == .worsening }.count

                        // Since Day 1
                        HStack {
                            Label("Since Day 1", systemImage: oc > 0
                                  ? "arrow.down.circle.fill"
                                  : oc < -5 ? "arrow.up.circle.fill" : "minus.circle.fill")
                                .foregroundColor(oc > 0 ? .green : oc < -5 ? .red : .orange)
                            Spacer()
                            Text(oc > 0
                                 ? "~\(Int(oc))% smaller"
                                 : oc < -5 ? "~\(Int(abs(oc)))% larger" : "Similar")
                                .font(.subheadline)
                                .foregroundColor(oc > 0 ? .green : oc < -5 ? .red : .orange)
                                .fontWeight(.medium)
                        }

                        // Healing days
                        HStack {
                            Label("Healing check-ins", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Spacer()
                            Text("\(hc)")
                                .foregroundColor(.green)
                                .fontWeight(.semibold)
                        }

                        // Stable days
                        HStack {
                            Label("Stable check-ins", systemImage: "minus.circle.fill")
                                .foregroundColor(.orange)
                            Spacer()
                            Text("\(sc)")
                                .foregroundColor(.orange)
                                .fontWeight(.semibold)
                        }

                        // Worsening (only if any)
                        if wc > 0 {
                            HStack {
                                Label("Worsening check-ins", systemImage: "exclamationmark.circle.fill")
                                    .foregroundColor(.red)
                                Spacer()
                                Text("\(wc)")
                                    .foregroundColor(.red)
                                    .fontWeight(.semibold)
                            }
                        }

                        Text("Each check-in is compared to the previous photo.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                // MARK: AI Vision comparison
                if injury.checkIns.count >= 2 {
                    Section("AI Comparison") {
                        if isRunningComparison {
                            HStack(spacing: 10) {
                                ProgressView().scaleEffect(0.85)
                                Text("Comparing latest vs previous photo…")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        } else if let cr = comparisonResult {
                            // Same area warning
                            if !cr.isSameArea {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text("Photo angle differs from previous")
                                        .font(.subheadline)
                                        .foregroundColor(.orange)
                                }
                            }

                            // Wound detected
                            HStack {
                                Label(cr.woundDetected ? "Wound visible" : "Wound not visible",
                                      systemImage: cr.woundDetected ? "eye.fill" : "eye.slash.fill")
                                    .foregroundColor(cr.woundDetected ? .primary : .orange)
                                Spacer()
                            }

                            // Size change
                            HStack {
                                Label("Size change", systemImage: cr.sizeChange == .reduced
                                      ? "arrow.down.circle.fill"
                                      : cr.sizeChange == .enlarged ? "arrow.up.circle.fill"
                                      : "minus.circle.fill")
                                    .foregroundColor(cr.sizeChange == .reduced ? .green
                                                     : cr.sizeChange == .enlarged ? .red : .orange)
                                Spacer()
                                Text(cr.sizeChange == .reduced
                                     ? "~\(Int(abs(cr.sizeDeltaPct)))% smaller"
                                     : cr.sizeChange == .enlarged
                                         ? "~\(Int(abs(cr.sizeDeltaPct)))% larger"
                                         : "Similar")
                                    .font(.subheadline)
                                    .foregroundColor(cr.sizeChange == .reduced ? .green
                                                     : cr.sizeChange == .enlarged ? .red : .orange)
                                    .fontWeight(.medium)
                            }

                            // Colour note
                            if !cr.colourNote.isEmpty {
                                Text(cr.colourNote)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            // Overall trend
                            HStack {
                                Label("Overall trend", systemImage: cr.overallTrend.icon)
                                    .foregroundColor(.primary)
                                Spacer()
                                Text(cr.overallTrend.label)
                                    .foregroundColor(cr.overallTrend.color)
                                    .fontWeight(.medium)
                            }
                        } else {
                            Text("Analysis runs automatically when 2+ photos are available.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        // Position accuracy note — always shown
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "info.circle")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 1)
                            Text("Accuracy depends on taking each photo from the same angle and distance.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // MARK: Photo comparison (previous vs latest)
                if injury.checkIns.count >= 2,
                   let prev = injury.checkIns.dropLast().last,
                   let latest = injury.checkIns.last {
                    Section("Previous vs Latest") {
                        HStack(spacing: 12) {
                            photoThumb(filename: prev.imagePath, label: "Previous",
                                       time: prev.shortDateTime, accent: false)
                            VStack(spacing: 4) {
                                let trend = comparisonResult?.overallTrend ?? latestTrend
                                Image(systemName: trend.icon)
                                    .font(.title2)
                                    .foregroundColor(trend.color)
                                Text(trend.label)
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(trend.color)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(width: 44)
                            photoThumb(filename: latest.imagePath, label: "Latest",
                                       time: latest.shortDateTime, accent: true)
                        }
                        .padding(.vertical, 4)
                    }
                }

                // MARK: All photos timeline
                if !injury.checkIns.isEmpty {
                    Section("All Photos (\(injury.checkIns.count))") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(Array(injury.checkIns.enumerated()), id: \.element.id) { i, ci in
                                    TimelineThumbnail(checkIn: ci, dayNumber: i,
                                                      isLatest: i == injury.checkIns.count - 1)
                                }
                            }
                            .padding(.vertical, 6)
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                }

                // MARK: Add photo button
                Section {
                    Button {
                        HapticFeedback.medium()
                        onAddPhoto()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "camera.fill")
                                .foregroundColor(injury.isActive ? .white : .secondary)
                                .frame(width: 32, height: 32)
                                .background(injury.isActive ? injury.type.color : Color(.systemGray4))
                                .clipShape(Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(injury.isActive ? "Add Progress Photo" : "Recovery Complete")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(injury.isActive ? .primary : .secondary)
                                if let last = injury.latestCheckIn {
                                    Text("Last: \(last.shortDateTime)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .disabled(!injury.isActive)
                }

                // MARK: Disclaimer
                Section {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 1)
                        Text("Educational guidance only — not a substitute for medical advice. In emergencies, call your local emergency number.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(injury.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear { runVisionComparison() }
    }

    // MARK: - Helpers

    private var shouldShowDoctorAlert: Bool {
        if injury.needsDoctorSuggestion { return true }
        if let cr = comparisonResult, cr.shouldSeeDoctor { return true }
        let daysSince = Calendar.current.dateComponents([.day], from: injury.date, to: Date()).day ?? 0
        let healed = injury.checkIns.filter { $0.trend == .healing }.count
        return daysSince >= 4 && healed == 0 && injury.checkIns.count >= 2
    }

    private func photoThumb(filename: String, label: String, time: String, accent: Bool) -> some View {
        VStack(spacing: 5) {
            Group {
                if let img = WoundProgressService.loadImage(filename: filename) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 100)
                        .clipped()
                        .cornerRadius(10)
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGray5))
                        .frame(maxWidth: .infinity)
                        .frame(height: 100)
                        .overlay(Image(systemName: "photo")
                            .foregroundColor(.secondary))
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(accent ? injury.type.color : Color.clear, lineWidth: 2)
            )
            Text(label)
                .font(.caption2)
                .fontWeight(accent ? .semibold : .regular)
                .foregroundColor(accent ? .primary : .secondary)
            Text(time)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func runVisionComparison() {
        guard !comparisonRan, injury.checkIns.count >= 2 else { return }
        guard let prevCI   = injury.checkIns.dropLast().last,
              let latestCI = injury.checkIns.last else { return }
        guard let prevImg  = WoundProgressService.loadImage(filename: prevCI.imagePath),
              let newImg   = WoundProgressService.loadImage(filename: latestCI.imagePath) else { return }

        comparisonRan      = true
        isRunningComparison = true

        WoundComparisonService.compare(
            newImage: newImg,
            previousImage: prevImg,
            injuryType: injury.type,
            consecutiveNonHealingDays: injury.consecutiveStableDays
        ) { result in
            self.comparisonResult    = result
            self.isRunningComparison = false
        }
    }
}

// MARK: - Timeline Thumbnail

struct TimelineThumbnail: View {
    let checkIn:  DailyCheckIn
    let dayNumber: Int
    let isLatest: Bool
    private var image: UIImage? { WoundProgressService.loadImage(filename: checkIn.imagePath) }

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let img = image {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipped()
                            .cornerRadius(10)
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.systemGray5))
                            .frame(width: 60, height: 60)
                            .overlay(
                                Image(systemName: "photo.fill")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            )
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isLatest ? Color.blue : Color.clear, lineWidth: 2)
                )

                Circle()
                    .fill(checkIn.trend.color)
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1.5))
                    .offset(x: 4, y: 4)
            }

            Text("Day \(dayNumber + 1)")
                .font(.system(size: 10, weight: isLatest ? .bold : .regular))
                .foregroundColor(isLatest ? .blue : .secondary)

            Text(checkIn.shortTime)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
    }
}

#Preview { HistoryView() }
