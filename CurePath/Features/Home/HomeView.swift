import SwiftUI

struct HomeView: View {
    @State private var showScanner          = false
    @State private var selectedGuideType: InjuryType?
    @State private var selectedForCheckIn: InjuryRecord?
    @ObservedObject private var dataManager = InjuryDataManager.shared
    @Environment(\.colorScheme) private var scheme
    
    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    scanHeroCard.padding(.horizontal).padding(.top, 8)
                    if let latest = dataManager.injuries.first {
                        latestInjuryCard(latest)
                            .padding(.horizontal)
                            .animation(.spring(response: 0.5), value: latest.id)
                    }
                    
                    if dataManager.injuries.count > 1 {
                        recentSection
                    }
                    guidesSection
                    
                    safetyNote.padding(.horizontal).padding(.bottom, 12)
                }
            }
            .navigationTitle("CurePath")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear { OrientationLockHelper.lockPortrait() }
        .sheet(isPresented: $showScanner) {
            ScannerView(isPresented: $showScanner)
        }
        .sheet(item: $selectedGuideType) { type in
            FirstAidGuideView(injuryType: type)
        }
        .sheet(item: $selectedForCheckIn) { injury in
            DailyCheckInView(injury: injury)
        }
    }
    
    // MARK: - Hero scan card
    private var scanHeroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("AI ASSISTANT")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundColor(.white.opacity(0.9)).tracking(1)
            }
            Text("Scan Injury")
                .font(.system(size: 34, weight: .bold)).foregroundColor(.white)
            Text("Take a breath. Let's handle this together, scan a wound for instant first aid guidance.")
                .font(.subheadline).foregroundColor(.white.opacity(0.75))
            
            Button { HapticFeedback.medium(); showScanner = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: "camera.fill")
                    Text("Start Scan").fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(Color.white.opacity(0.22)).foregroundColor(.white).cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.3), lineWidth: 1))
            }
        }
        .padding(22)
        .background(
            LinearGradient(
                colors: [Color(red:0.18,green:0.44,blue:0.96), Color(red:0.10,green:0.30,blue:0.78)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .cornerRadius(22)
        .shadow(color: Color.blue.opacity(0.35), radius: 16, x: 0, y: 8)
    }
    
    // MARK: - Latest injury (full-width highlighted card)
    private func latestInjuryCard(_ injury: InjuryRecord) -> some View {
        // Theme-aware colours
        let cardBG: Color = scheme == .dark ? Color(.systemGray6) : .white
        let border: Color = scheme == .dark
        ? Color.white.opacity(0.09)
        : injury.type.color.opacity(0.2)
        
        return VStack(alignment: .leading, spacing: 14) {
            
            // Header row
            HStack(spacing: 4) {
                Image(systemName: "clock.fill").font(.caption2).foregroundColor(injury.type.color)
                Text("Latest Injury")
                    .font(.caption).fontWeight(.semibold).foregroundColor(injury.type.color)
                Spacer()
                Text(injury.isActive ? "Active" : "Healed")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundColor(injury.isActive ? .green : .gray)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background((injury.isActive ? Color.green : Color.gray).opacity(0.12))
                    .cornerRadius(6)
            }
            
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(injury.type.color.opacity(0.15)).frame(width: 52, height: 52)
                    Image(systemName: injury.type.icon).font(.system(size: 22)).foregroundColor(injury.type.color)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(injury.title).font(.headline).lineLimit(1)
                    Text("\(injury.formattedDate)  ·  Day \(injury.currentDay) / \(injury.totalDays)")
                        .font(.caption).foregroundColor(.secondary)
                    if let trend = injury.latestCheckIn?.trend, trend != .baseline {
                        HStack(spacing: 4) {
                            Image(systemName: trend.icon).font(.caption2).foregroundColor(trend.color)
                            Text(trend.label).font(.caption).fontWeight(.medium).foregroundColor(trend.color)
                        }
                    }
                }
            }
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.12)).frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(colors: [injury.type.color.opacity(0.6), injury.type.color],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * injury.progress, height: 8)
                        .animation(.spring(response: 0.6), value: injury.progress)
                }
            }.frame(height: 8)
            
            // Encouragement text
            HStack(spacing: 8) {
                Image(systemName: "heart.fill").font(.caption).foregroundColor(injury.type.color)
                Text(EncouragementSystem.message(for: injury))
                    .font(.caption).foregroundColor(injury.type.color).lineLimit(2)
            }
            .padding(10).frame(maxWidth: .infinity, alignment: .leading)
            .background(injury.type.color.opacity(0.08)).cornerRadius(10)
            
            // Log progress button (active only)
            if injury.isActive {
                Button { HapticFeedback.medium(); selectedForCheckIn = injury } label: {
                    HStack {
                        Image(systemName: "camera.fill").font(.subheadline)
                        Text("Log Today's Progress").font(.subheadline).fontWeight(.medium)
                        Spacer()
                        Image(systemName: "arrow.right.circle.fill").font(.title3)
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 12).padding(.horizontal, 14)
                    .background(injury.type.color).cornerRadius(12)
                }
            }
        }
        .padding(18)
        .background(cardBG)
        .cornerRadius(18)
        .shadow(
            color: scheme == .dark ? .clear : injury.type.color.opacity(0.12),
            radius: 12, x: 0, y: 4
        )
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(border, lineWidth: 1.5))
    }
    
    // MARK: - Recent injuries list (compact rows)
    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Injuries")
                .font(.title3).fontWeight(.bold).padding(.horizontal)
            
            VStack(spacing: 10) {
                ForEach(Array(dataManager.injuries.dropFirst().prefix(2))) { injury in
                    recentRow(injury)
                        .padding(.horizontal)
                }
            }
        }
    }
    
    private func recentRow(_ injury: InjuryRecord) -> some View {
        let cardBG: Color = scheme == .dark ? Color(.systemGray6) : .white
        let border: Color = scheme == .dark ? Color.white.opacity(0.08) : Color.clear
        let trend = injury.latestCheckIn?.trend ?? .baseline
        
        return HStack(spacing: 12) {
            ZStack {
                Circle().fill(injury.type.color.opacity(0.14)).frame(width: 40, height: 40)
                Image(systemName: injury.type.icon).font(.system(size: 16)).foregroundColor(injury.type.color)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(injury.title).font(.subheadline).fontWeight(.semibold).lineLimit(1)
                HStack(spacing: 5) {
                    Text(injury.formattedDate).font(.caption).foregroundColor(.secondary)
                    if trend != .baseline {
                        Circle().fill(Color.secondary.opacity(0.4)).frame(width: 3, height: 3)
                        Image(systemName: trend.icon).font(.system(size: 9)).foregroundColor(trend.color)
                        Text(trend.label).font(.caption).foregroundColor(trend.color)
                    }
                }
            }
            Spacer()
            Text(injury.isActive ? "Active" : "Healed")
                .font(.caption2).fontWeight(.semibold)
                .foregroundColor(injury.isActive ? .green : .gray)
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background((injury.isActive ? Color.green : Color.gray).opacity(0.12))
                .cornerRadius(5)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(cardBG)
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(scheme == .dark ? 0 : 0.04), radius: 5, x: 0, y: 2)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(border, lineWidth: 1))
    }
    private var guidesSection: some View {
        VStack(alignment: .leading) {
            Text("First-Aid Guides")
                .font(.title3).fontWeight(.bold).padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    HomeGuideCard(
                        title: "Cuts",       subtitle: "Stop bleeding",
                        icon: "bandage.fill",                iconColor: .red,
                        tileBG: Color(red:1.0,green:0.92,blue:0.92)
                    ) { selectedGuideType = .cut;        HapticFeedback.light() }

                    HomeGuideCard(
                        title: "Burns",      subtitle: "Cool & cover",
                        icon: "flame.fill",                  iconColor: .orange,
                        tileBG: Color(red:1.0,green:0.95,blue:0.88)
                    ) { selectedGuideType = .burn;       HapticFeedback.light() }

                    HomeGuideCard(
                        title: "Abrasions",  subtitle: "Clean & protect",
                        icon: "waveform.path.ecg",           iconColor: .blue,
                        tileBG: Color(red:0.90,green:0.95,blue:1.0)
                    ) { selectedGuideType = .abrasion;   HapticFeedback.light() }

                    HomeGuideCard(
                        title: "Laceration", subtitle: "Deep wound care",
                        icon: "scissors",                    iconColor: Color(red:0.8,green:0.1,blue:0.2),
                        tileBG: Color(red:1.0,green:0.90,blue:0.90)
                    ) { selectedGuideType = .laceration; HapticFeedback.light() }

                    HomeGuideCard(
                        title: "Venom / Bite", subtitle: "Stay calm & act fast",
                        icon: "ant.fill",                    iconColor: Color(red:0.5,green:0.15,blue:0.6),
                        tileBG: Color(red:0.95,green:0.88,blue:1.0)
                    ) { selectedGuideType = .venomBite;  HapticFeedback.light() }

                    HomeGuideCard(
                        title: "Sprain",     subtitle: "RICE method",
                        icon: "figure.walk",                 iconColor: Color(red:0.1,green:0.5,blue:0.85),
                        tileBG: Color(red:0.88,green:0.95,blue:1.0)
                    ) { selectedGuideType = .sprain;     HapticFeedback.light() }

                    HomeGuideCard(
                        title: "Nosebleed",  subtitle: "Pinch & stay calm",
                        icon: "nose",                        iconColor: Color(red:0.85,green:0.2,blue:0.3),
                        tileBG: Color(red:1.0,green:0.91,blue:0.91)
                    ) { selectedGuideType = .nosebleed;  HapticFeedback.light() }
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
            }
            .frame(height: 200)
        }
    }
    
    //Safety disclaimer
    private var safetyNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.secondary)
                .font(.subheadline)
                .padding(.top, 1)
            
            Text("CurePath is for educational guidance only, It's not a substitute for professional medical advice. In emergencies, call your local emergency number.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading) 
        .padding(14)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Guide card (theme-aware)
struct HomeGuideCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    let tileBG: Color
    let action: () -> Void

    @State private var pressed = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {

                // Icon tile
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(scheme == .dark ? iconColor.opacity(0.22) : tileBG)
                        .frame(width: 58, height: 58)

                    Image(systemName: icon)
                        .font(.system(size: 26))
                        .foregroundColor(iconColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .frame(width: 160, height: 160, alignment: .topLeading)
            .padding(14)
            .background(scheme == .dark ? Color(.systemGray6) : Color(.systemBackground))
            .cornerRadius(16)
            .shadow(
                color: Color.black.opacity(scheme == .dark ? 0 : (pressed ? 0.12 : 0.06)),
                radius: pressed ? 12 : 8,
                x: 0,
                y: pressed ? 5 : 2
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        scheme == .dark ? Color.white.opacity(0.08) : Color.clear,
                        lineWidth: 1
                    )
            )
            .scaleEffect(pressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: pressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(
            minimumDuration: 0,
            pressing: { isPressing in
                pressed = isPressing
            },
            perform: {}
        )
    }
}

// InjuryType must be Identifiable for .sheet(item:)
extension InjuryType: Identifiable { var id: String { rawValue } }

#Preview { HomeView() }
