import Foundation
import SwiftUI
enum InjuryType: String, Codable, CaseIterable {
    case cut        = "Cut"
    case burn       = "Burns"
    case abrasion   = "Abrasions"
    case laceration = "Laceration"
    case venomBite  = "Venom / Bite"
    case sprain     = "Sprain"
    case nosebleed  = "Nosebleed"
    case normal     = "Normal"
    case unknown    = "Unknown"

    var icon: String {
        switch self {
        case .cut:        return "bandage.fill"
        case .burn:       return "flame.fill"
        case .abrasion:   return "waveform.path.ecg"
        case .laceration: return "scissors"
        case .venomBite:  return "ant.fill"
        case .sprain:     return "figure.walk"
        case .nosebleed:  return "nose"
        case .normal:     return "checkmark.circle.fill"
        case .unknown:    return "questionmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .cut:        return .red
        case .burn:       return .orange
        case .abrasion:   return .blue
        case .laceration: return Color(red: 0.8, green: 0.1, blue: 0.2)
        case .venomBite:  return Color(red: 0.5, green: 0.15, blue: 0.6)
        case .sprain:     return Color(red: 0.1, green: 0.5, blue: 0.85)
        case .nosebleed:  return Color(red: 0.85, green: 0.2, blue: 0.3)
        case .normal:     return .green
        case .unknown:    return .gray
        }
    }

    var displayName: String { rawValue }

    var animatedSteps: [FirstAidAnimationStep] {
        switch self {
        case .cut:
            return [
                FirstAidAnimationStep(stepNumber: 1, title: "Wash Your Hands",
                    instruction: "Clean your hands thoroughly with soap and water",
                    animationType: .handWashing, duration: 20,
                    voiceText: "First, wash your hands thoroughly with soap and water to prevent infection"),
                FirstAidAnimationStep(stepNumber: 2, title: "Apply Pressure",
                    instruction: "Press clean cloth on wound for 5 minutes",
                    animationType: .applyPressure, duration: 300,
                    voiceText: "Apply gentle pressure with a clean cloth for 5 minutes to stop the bleeding"),
                FirstAidAnimationStep(stepNumber: 3, title: "Clean the Wound",
                    instruction: "Rinse gently with clean water",
                    animationType: .cleanWound, duration: 15,
                    voiceText: "Rinse the wound gently with clean water. Avoid using hydrogen peroxide"),
                FirstAidAnimationStep(stepNumber: 4, title: "Apply Bandage",
                    instruction: "Cover with sterile bandage",
                    animationType: .applyBandage, duration: 0,
                    voiceText: "Cover the wound with a sterile bandage to keep it clean")
            ]
        case .burn:
            return [
                FirstAidAnimationStep(stepNumber: 1, title: "Remove from Heat",
                    instruction: "Move away from heat source immediately",
                    animationType: .moveAway, duration: 0,
                    voiceText: "First, remove yourself from the heat source and remove any jewelry near the burn"),
                FirstAidAnimationStep(stepNumber: 2, title: "Cool the Burn",
                    instruction: "Run cool water for 5-10 minutes",
                    animationType: .coolWithWater, duration: 450,
                    voiceText: "Run cool, not cold, water over the burn for 5 to 10 minutes. Do not use ice"),
                FirstAidAnimationStep(stepNumber: 3, title: "Cover Gently",
                    instruction: "Use sterile, non-stick bandage",
                    animationType: .coverGently, duration: 0,
                    voiceText: "Cover the burn with a sterile, non-adhesive bandage. Do not break any blisters")
            ]
        case .abrasion:
            return [
                FirstAidAnimationStep(stepNumber: 1, title: "Stop Activity",
                    instruction: "Assess the injury and stop what you're doing",
                    animationType: .stopAndAssess, duration: 0,
                    voiceText: "Stop your activity and gently assess the injury"),
                FirstAidAnimationStep(stepNumber: 2, title: "Clean Thoroughly",
                    instruction: "Rinse with water and remove debris",
                    animationType: .cleanWound, duration: 30,
                    voiceText: "Rinse the area with clean water for several minutes to remove dirt and debris"),
                FirstAidAnimationStep(stepNumber: 3, title: "Apply Ointment",
                    instruction: "Use antibiotic ointment",
                    animationType: .applyOintment, duration: 0,
                    voiceText: "Apply a thin layer of antibiotic ointment to prevent infection"),
                FirstAidAnimationStep(stepNumber: 4, title: "Bandage",
                    instruction: "Cover with breathable bandage",
                    animationType: .applyBandage, duration: 0,
                    voiceText: "Cover with a breathable bandage and change it daily")
            ]
        case .laceration:
            return [
                FirstAidAnimationStep(stepNumber: 1, title: "Wash Your Hands",
                    instruction: "Wash hands with soap before touching the wound",
                    animationType: .handWashing, duration: 20,
                    voiceText: "First, thoroughly wash your hands to prevent infection"),
                FirstAidAnimationStep(stepNumber: 2, title: "Control Bleeding",
                    instruction: "Apply firm pressure with a clean cloth for 10 min",
                    animationType: .applyPressure, duration: 300,
                    voiceText: "Apply firm, continuous pressure with a clean cloth for at least ten minutes"),
                FirstAidAnimationStep(stepNumber: 3, title: "Rinse the Wound",
                    instruction: "Gently flush with clean water",
                    animationType: .cleanWound, duration: 15,
                    voiceText: "Gently rinse the laceration with clean running water"),
                FirstAidAnimationStep(stepNumber: 4, title: "Close & Cover",
                    instruction: "Use butterfly strips or sterile bandage",
                    animationType: .applyBandage, duration: 0,
                    voiceText: "Use butterfly strips if available, then cover with a sterile bandage")
            ]
        case .venomBite:
            return [
                FirstAidAnimationStep(stepNumber: 1, title: "Move Away Safely",
                    instruction: "Leave the area — do NOT try to catch the animal",
                    animationType: .moveAway, duration: 0,
                    voiceText: "Move away from the animal immediately. Do not attempt to catch or handle it"),
                FirstAidAnimationStep(stepNumber: 2, title: "Keep Calm & Still",
                    instruction: "Sit or lie down — reduce movement of bitten limb",
                    animationType: .stopAndAssess, duration: 0,
                    voiceText: "Stay calm and keep the bitten limb as still as possible to slow venom spread"),
                FirstAidAnimationStep(stepNumber: 3, title: "Rinse the Bite",
                    instruction: "Wash gently with soap and water",
                    animationType: .cleanWound, duration: 30,
                    voiceText: "Gently wash the bite area with soap and clean water for thirty seconds"),
                FirstAidAnimationStep(stepNumber: 4, title: "Cover the Area",
                    instruction: "Use sterile dressing — do NOT apply tourniquet",
                    animationType: .applyBandage, duration: 0,
                    voiceText: "Apply a loose sterile dressing. Never use a tourniquet or try to suck out venom")
            ]
        case .sprain:
            return [
                FirstAidAnimationStep(stepNumber: 1, title: "Rest",
                    instruction: "Stop activity and rest the injured joint",
                    animationType: .stopAndAssess, duration: 0,
                    voiceText: "Stop all activity immediately and rest the injured joint"),
                FirstAidAnimationStep(stepNumber: 2, title: "Ice",
                    instruction: "Apply ice pack wrapped in cloth for 15 min",
                    animationType: .coolWithWater, duration: 450,
                    voiceText: "Apply an ice pack wrapped in a cloth for fifteen minutes to reduce swelling"),
                FirstAidAnimationStep(stepNumber: 3, title: "Compression",
                    instruction: "Wrap with elastic bandage — not too tight",
                    animationType: .applyBandage, duration: 0,
                    voiceText: "Wrap the joint firmly with an elastic bandage. Check that circulation is not cut off"),
                FirstAidAnimationStep(stepNumber: 4, title: "Elevation",
                    instruction: "Raise the limb above heart level",
                    animationType: .applyOintment, duration: 0,
                    voiceText: "Elevate the injured limb above the level of your heart to reduce swelling")
            ]
        case .nosebleed:
            return [
                FirstAidAnimationStep(stepNumber: 1, title: "Sit & Lean Forward",
                    instruction: "Sit upright — lean slightly forward",
                    animationType: .stopAndAssess, duration: 0,
                    voiceText: "Sit upright and lean slightly forward to prevent swallowing blood"),
                FirstAidAnimationStep(stepNumber: 2, title: "Pinch the Nose",
                    instruction: "Pinch soft part of nose firmly for 10-15 min",
                    animationType: .applyPressure, duration: 450,
                    voiceText: "Pinch the soft part of your nose firmly and breathe through your mouth"),
                FirstAidAnimationStep(stepNumber: 3, title: "Apply Cold Compress",
                    instruction: "Place a cold damp cloth on the bridge of nose",
                    animationType: .coolWithWater, duration: 180,
                    voiceText: "Place a cold damp cloth across the bridge of your nose to help constrict blood vessels"),
                FirstAidAnimationStep(stepNumber: 4, title: "Rest Quietly",
                    instruction: "Avoid blowing nose for several hours",
                    animationType: .coverGently, duration: 0,
                    voiceText: "Rest and avoid blowing your nose, bending down, or heavy lifting for several hours")
            ]
        case .normal, .unknown: return []
        }
    }
}

// MARK: - Daily Check-In
struct DailyCheckIn: Identifiable, Codable {
    let id: UUID
    let date: Date
    let imagePath: String

    let boundingBoxArea: Double
    let woundPixelDensity: Double
    let woundScore: Double
    let deltaScore: Double?
    let trend: WoundTrend

    var formattedDate: String {
        let f = DateFormatter(); f.dateStyle = .medium; return f.string(from: date)
    }
    var shortDateTime: String {
        let f = DateFormatter(); f.dateFormat = "MMM d · h:mm a"; return f.string(from: date)
    }
    var shortTime: String {
        let f = DateFormatter(); f.dateFormat = "h:mm a"; return f.string(from: date)
    }
    var dayLabel: String {
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f.string(from: date)
    }
}

enum WoundTrend: String, Codable {
    case healing   = "Healing"
    case stable    = "Stable"
    case worsening = "Worsening"
    case baseline  = "Baseline"

    var icon: String {
        switch self {
        case .healing:   return "arrow.down.circle.fill"
        case .stable:    return "minus.circle.fill"
        case .worsening: return "arrow.up.circle.fill"
        case .baseline:  return "circle.fill"
        }
    }
    var color: Color {
        switch self {
        case .healing:   return .green
        case .stable:    return .orange
        case .worsening: return .red
        case .baseline:  return .blue
        }
    }
    var label: String {
        switch self {
        case .healing:   return "Healing"
        case .stable:    return "No change"
        case .worsening: return "Worsening"
        case .baseline:  return "Day 1 scan"
        }
    }
}

// MARK: - InjuryRecord
struct InjuryRecord: Identifiable, Codable {
    let id: UUID
    var title: String
    var type: InjuryType
    var date: Date
    var currentDay: Int
    let totalDays: Int
    var isActive: Bool
    var confidence: Float
    var imagePath: String

    var checkIns: [DailyCheckIn]
    var consecutiveStableDays: Int
    var needsDoctorSuggestion: Bool

    init(id: UUID = UUID(), title: String, type: InjuryType, date: Date,
         currentDay: Int, totalDays: Int, isActive: Bool, confidence: Float,
         imagePath: String, checkIns: [DailyCheckIn] = [],
         consecutiveStableDays: Int = 0, needsDoctorSuggestion: Bool = false) {
        self.id = id; self.title = title; self.type = type; self.date = date
        self.currentDay = currentDay; self.totalDays = totalDays
        self.isActive = isActive; self.confidence = confidence
        self.imagePath = imagePath; self.checkIns = checkIns
        self.consecutiveStableDays = consecutiveStableDays
        self.needsDoctorSuggestion = needsDoctorSuggestion
    }

    enum CodingKeys: String, CodingKey {
        case id, title, type, date, currentDay, totalDays, isActive,
             confidence, imagePath, checkIns, consecutiveStableDays, needsDoctorSuggestion
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                    = try c.decode(UUID.self,       forKey: .id)
        title                 = try c.decode(String.self,     forKey: .title)
        type                  = try c.decode(InjuryType.self, forKey: .type)
        date                  = try c.decode(Date.self,       forKey: .date)
        currentDay            = try c.decode(Int.self,        forKey: .currentDay)
        totalDays             = try c.decode(Int.self,        forKey: .totalDays)
        isActive              = try c.decode(Bool.self,       forKey: .isActive)
        confidence            = try c.decode(Float.self,      forKey: .confidence)
        imagePath             = try c.decode(String.self,     forKey: .imagePath)
        checkIns              = (try? c.decode([DailyCheckIn].self, forKey: .checkIns)) ?? []
        consecutiveStableDays = (try? c.decode(Int.self,  forKey: .consecutiveStableDays)) ?? 0
        needsDoctorSuggestion = (try? c.decode(Bool.self, forKey: .needsDoctorSuggestion)) ?? false
    }

    var progress: Double {
        guard totalDays > 0 else { return 0 }
        return Double(currentDay) / Double(totalDays)
    }
    var formattedDate: String {
        let f = DateFormatter(); f.dateStyle = .medium; return f.string(from: date)
    }
    var latestCheckIn:  DailyCheckIn? { checkIns.last }
    var previousCheckIn: DailyCheckIn? { checkIns.count >= 2 ? checkIns[checkIns.count - 2] : nil }
}
struct FirstAidAnimationStep: Identifiable {
    let id = UUID()
    let stepNumber: Int
    let title: String
    let instruction: String
    let animationType: AnimationType
    let duration: TimeInterval
    let voiceText: String
}
enum AnimationType {
    case handWashing, applyPressure, cleanWound, applyBandage
    case moveAway, coolWithWater, coverGently, stopAndAssess, applyOintment
    case visitDoctor
}

enum InjurySeverity: String, Codable {
    case minor = "Minor"; case moderate = "Moderate"; case severe = "Severe"
    var color: Color {
        switch self { case .minor: return .green; case .moderate: return .orange; case .severe: return .red }
    }
}
enum RecoveryStatus: String, Codable {
    case active = "Active"; case completed = "Completed"; case needsAttention = "Needs Attention"
}

struct FirstAidStep: Identifiable {
    let id: UUID
    let stepNumber: Int
    let title: String
    let description: String
    let icon: String?
    let illustrationIcon: String
    let duration: TimeInterval?
    init(id: UUID = UUID(), stepNumber: Int, title: String, description: String,
         icon: String? = nil, illustrationIcon: String = "cross.case.fill",
         duration: TimeInterval? = nil) {
        self.id = id; self.stepNumber = stepNumber; self.title = title
        self.description = description; self.icon = icon
        self.illustrationIcon = illustrationIcon; self.duration = duration
    }
}

struct FirstAidGuide: Identifiable {
    let id: UUID
    let injuryType: InjuryType
    let title: String
    let subtitle: String
    let steps: [FirstAidStep]
    let warnings: [String]
    let whenToSeekHelp: [String]
    init(id: UUID = UUID(), injuryType: InjuryType, title: String, subtitle: String,
         steps: [FirstAidStep], warnings: [String] = [], whenToSeekHelp: [String] = []) {
        self.id = id; self.injuryType = injuryType; self.title = title
        self.subtitle = subtitle; self.steps = steps; self.warnings = warnings
        self.whenToSeekHelp = whenToSeekHelp
    }
}

extension FirstAidGuide {

    // MARK: - Cuts Guide (timers halved: bleeding → 300s, wound clean → 8s)
    static let cutsGuide = FirstAidGuide(injuryType: .cut, title: "Cuts", subtitle: "Stop bleeding & protect",
        steps: [
            FirstAidStep(stepNumber: 1, title: "Wash Your Hands",
                description: "Clean your hands thoroughly with soap and water to prevent infection.",
                icon: "hand.wash.fill", illustrationIcon: "hand.raised.fill", duration: nil),
            FirstAidStep(stepNumber: 2, title: "Stop the Bleeding",
                description: "Apply gentle pressure with a clean cloth or bandage for 5 minutes.",
                icon: "bandage.fill", illustrationIcon: "hand.point.down.fill", duration: 300),
            FirstAidStep(stepNumber: 3, title: "Clean the Wound",
                description: "Rinse the cut with clean water. Avoid hydrogen peroxide or iodine.",
                icon: "drop.fill", illustrationIcon: "shower.fill", duration: 8),
            FirstAidStep(stepNumber: 4, title: "Apply Antibiotic",
                description: "Apply a thin layer of antibiotic ointment to prevent infection.",
                icon: "cross.case.fill", illustrationIcon: "cross.vial.fill", duration: nil),
            FirstAidStep(stepNumber: 5, title: "Cover the Cut",
                description: "Apply a sterile bandage or gauze pad. Change daily or when wet.",
                icon: "rectangle.fill", illustrationIcon: "bandage.fill", duration: nil),
            FirstAidStep(stepNumber: 6, title: "Visit a Doctor",
                description: "See a healthcare professional for proper examination. Follow any prescribed medication or dressing changes. Professional care prevents infection and speeds recovery.",
                icon: "stethoscope", illustrationIcon: "stethoscope", duration: nil)
        ],
        warnings: ["Avoid touching the wound with dirty hands", "Don't remove embedded objects", "Check for signs of infection daily"],
        whenToSeekHelp: ["Bleeding doesn't stop after 10 minutes", "The cut is deep or jagged", "Signs of infection appear", "The injury is on the face, hand, or joint"])
    static let burnsGuide = FirstAidGuide(injuryType: .burn, title: "Burns", subtitle: "Cool & cover",
        steps: [
            FirstAidStep(stepNumber: 1, title: "Remove from Heat",
                description: "Move away from the heat source immediately. Remove jewelry near the burn.",
                icon: "flame.fill", illustrationIcon: "figure.walk", duration: nil),
            FirstAidStep(stepNumber: 2, title: "Cool the Burn",
                description: "Run cool (not cold) water over the burn for 7-10 minutes. Do not use ice.",
                icon: "drop.fill", illustrationIcon: "shower.fill", duration: 450),
            FirstAidStep(stepNumber: 3, title: "Protect the Area",
                description: "Cover with a sterile, non-adhesive bandage. Don't break blisters.",
                icon: "bandage.fill", illustrationIcon: "bandage.fill", duration: nil),
            FirstAidStep(stepNumber: 4, title: "Take Pain Relief",
                description: "Consider over the counter pain medication if needed.",
                icon: "pills.fill", illustrationIcon: "pills.circle.fill", duration: nil),
            FirstAidStep(stepNumber: 5, title: "Visit a Doctor",
                description: "See a healthcare professional for proper assessment. Follow any prescribed medication, dressings, or wound care instructions to prevent infection.",
                icon: "stethoscope", illustrationIcon: "stethoscope", duration: nil)
        ],
        warnings: ["Never apply ice directly to a burn", "Don't use butter or oil on fresh burns", "Avoid breaking blisters"],
        whenToSeekHelp: ["The burn is larger than 3 inches", "It's a deep burn", "The burn is on the face, hands or feet", "Signs of infection develop"])

    static let abrasionsGuide = FirstAidGuide(injuryType: .abrasion, title: "Abrasions", subtitle: "Clean and protect",
        steps: [
            FirstAidStep(stepNumber: 1, title: "Stop the Activity",
                description: "Stop what you're doing and assess the injury.",
                icon: "hand.raised.fill", illustrationIcon: "figure.stand", duration: nil),
            FirstAidStep(stepNumber: 2, title: "Clean the Wound",
                description: "Rinse with clean water for 1-2 minutes. Gently remove dirt.",
                icon: "drop.fill", illustrationIcon: "shower.fill", duration: 15),
            FirstAidStep(stepNumber: 3, title: "Apply Antibiotic",
                description: "Apply a thin layer of antibiotic ointment to prevent infection.",
                icon: "cross.case.fill", illustrationIcon: "cross.vial.fill", duration: nil),
            FirstAidStep(stepNumber: 4, title: "Cover the Wound",
                description: "Use a non-stick bandage. Change the dressing daily.",
                icon: "bandage.fill", illustrationIcon: "bandage.fill", duration: nil),
            FirstAidStep(stepNumber: 5, title: "Visit a Doctor",
                description: "See a healthcare professional if the wound is deep or shows infection signs. Follow prescribed medication and dressing instructions for full recovery.",
                icon: "stethoscope", illustrationIcon: "stethoscope", duration: nil)
        ],
        warnings: ["Don't use alcohol or hydrogen peroxide", "Watch for signs of infection", "Keep the wound moist"],
        whenToSeekHelp: ["The wound is deep or covers a large area", "You can't remove all debris", "Signs of infection develop"])

    // MARK: - Laceration Guide (timers halved: pressure → 300s, rinse → 8s)
    static let lacerationGuide = FirstAidGuide(injuryType: .laceration, title: "Laceration", subtitle: "Deep wound — act fast",
        steps: [
            FirstAidStep(stepNumber: 1, title: "Protect Yourself First",
                description: "If available, put on disposable gloves before touching the wound to prevent cross-infection.",
                icon: "hand.raised.fill", illustrationIcon: "hand.raised.fill", duration: nil),
            FirstAidStep(stepNumber: 2, title: "Control Bleeding",
                description: "Apply firm, continuous pressure with a clean cloth for at least 5 minutes without lifting to check.",
                icon: "bandage.fill", illustrationIcon: "hand.point.down.fill", duration: 300),
            FirstAidStep(stepNumber: 3, title: "Rinse the Wound",
                description: "Gently flush the laceration with clean running water. Remove visible debris carefully.",
                icon: "drop.fill", illustrationIcon: "shower.fill", duration: 8),
            FirstAidStep(stepNumber: 4, title: "Close the Wound",
                description: "Use butterfly closures or sterile steri strips to hold edges together. Do NOT close puncture wounds.",
                icon: "scissors", illustrationIcon: "minus.square.fill", duration: nil),
            FirstAidStep(stepNumber: 5, title: "Cover & Elevate",
                description: "Apply a sterile bandage and elevate the limb above heart level to reduce bleeding.",
                icon: "rectangle.fill", illustrationIcon: "arrow.up.circle.fill", duration: nil),
            FirstAidStep(stepNumber: 6, title: "Visit a Doctor",
                description: "Lacerations often require stitches or surgical closure. See a doctor immediately especially if the wound is deep, gaping, or won't stop bleeding.",
                icon: "stethoscope", illustrationIcon: "stethoscope", duration: nil)
        ],
        warnings: ["Never probe the wound with fingers or objects", "Don't remove large embedded objects", "Deep lacerations may need stitches within 6 hours"],
        whenToSeekHelp: ["The wound is deeper than 0.5cm or won't close", "Bleeding doesn't stop after 10 minutes", "The wound is on the face, hand, or joint", "Numbness or loss of movement near the wound"])

    // MARK: - Venom / Bite Guide
    static let venomBiteGuide = FirstAidGuide(injuryType: .venomBite, title: "Venom / Bite", subtitle: "Stay calm and act fast",
        steps: [
            FirstAidStep(stepNumber: 1, title: "Move Away Safely",
                description: "Leave the area immediately. Do NOT try to catch, handle, or kill the animal — you could be bitten again.",
                icon: "figure.walk", illustrationIcon: "figure.walk", duration: nil),
            FirstAidStep(stepNumber: 2, title: "Note the Animal",
                description: "Try to remember the animal's appearance (colour, size, markings) from a safe distance. This helps doctors identify the venom.",
                icon: "eye.fill", illustrationIcon: "eye.fill", duration: nil),
            FirstAidStep(stepNumber: 3, title: "Keep Still & Calm",
                description: "Sit or lie down. Immobilise the bitten limb at or below heart level. Restrict movement to slow venom spread.",
                icon: "figure.stand", illustrationIcon: "figure.stand", duration: nil),
            FirstAidStep(stepNumber: 4, title: "Remove Constrictors",
                description: "Gently remove rings, watches, or tight clothing near the bite site — swelling will occur rapidly.",
                icon: "hand.raised.fill", illustrationIcon: "hand.raised.fill", duration: nil),
            FirstAidStep(stepNumber: 5, title: "Rinse the Bite",
                description: "Wash gently with soap and clean water for 30 seconds. Do NOT suck out venom, cut the bite, or apply a tourniquet.",
                icon: "drop.fill", illustrationIcon: "shower.fill", duration: 15),
            FirstAidStep(stepNumber: 6, title: "Monitor Symptoms",
                description: "Watch for swelling, difficulty breathing, dizziness, or nausea. Note the time of the bite for medical responders.",
                icon: "clock.fill", illustrationIcon: "clock.badge.exclamationmark.fill", duration: nil),
            FirstAidStep(stepNumber: 7, title: "Visit a Doctor",
                description: "Seek emergency medical attention immediately for all venomous bites. Carry the person if they cannot walk. Do not let them exert themselves.",
                icon: "stethoscope", illustrationIcon: "cross.circle.fill", duration: nil)
        ],
        warnings: ["Never apply a tourniquet", "Do not cut or suck venom from the bite", "Do not apply ice directly to the bite", "Avoid alcohol or caffeine — they accelerate venom absorption"],
        whenToSeekHelp: ["Any suspected venomous snake, spider, or insect bite", "Rapid swelling, difficulty breathing, or anaphylaxis", "Dizziness, nausea, or loss of consciousness", "Multiple stings or bites"])

    // MARK: - Sprain Guide (timers halved: ice → 450s)
    static let sprainGuide = FirstAidGuide(injuryType: .sprain, title: "Sprain", subtitle: "RICE method",
        steps: [
            FirstAidStep(stepNumber: 1, title: "Rest",
                description: "Stop your activity immediately. Avoid putting weight on or moving the injured joint.",
                icon: "figure.stand", illustrationIcon: "figure.stand", duration: nil),
            FirstAidStep(stepNumber: 2, title: "Ice",
                description: "Apply an ice pack wrapped in a cloth for 15 minutes. Never apply ice directly to skin.",
                icon: "snowflake", illustrationIcon: "snowflake.circle.fill", duration: 450),
            FirstAidStep(stepNumber: 3, title: "Compression",
                description: "Wrap the joint firmly with an elastic bandage snug but not so tight it cuts off circulation. Check for tingling or numbness.",
                icon: "bandage.fill", illustrationIcon: "bandage.fill", duration: nil),
            FirstAidStep(stepNumber: 4, title: "Elevation",
                description: "Raise the injured limb above heart level on pillows or a raised surface to reduce swelling.",
                icon: "arrow.up.circle.fill", illustrationIcon: "arrow.up.circle.fill", duration: nil),
            FirstAidStep(stepNumber: 5, title: "Pain Relief",
                description: "Consider an over the counter antiinflammatory (e.g. ibuprofen) to reduce pain and swelling.",
                icon: "pills.fill", illustrationIcon: "pills.circle.fill", duration: nil),
            FirstAidStep(stepNumber: 6, title: "Visit a Doctor",
                description: "See a healthcare professional to rule out fractures or ligament tears, especially if you cannot bear weight. Follow any physiotherapy or immobilisation instructions.",
                icon: "stethoscope", illustrationIcon: "stethoscope", duration: nil)
        ],
        warnings: ["Don't apply heat in the first 48 hours", "Avoid massaging the injury early on", "Do not walk on a severe sprain without support"],
        whenToSeekHelp: ["You cannot bear weight on the joint", "Severe swelling or bruising appears immediately", "The joint looks deformed", "Pain is severe or worsening"])

    // MARK: - Nosebleed Guide (timers halved: pinch → 450s, cold compress → 90s)
    static let nosebleedGuide = FirstAidGuide(injuryType: .nosebleed, title: "Nosebleed", subtitle: "Pinch & stay calm",
        steps: [
            FirstAidStep(stepNumber: 1, title: "Sit Upright",
                description: "Sit upright and lean slightly forward not backward. This prevents blood from draining into the throat and being swallowed.",
                icon: "figure.stand", illustrationIcon: "figure.stand", duration: nil),
            FirstAidStep(stepNumber: 2, title: "Pinch the Nose",
                description: "Pinch the soft part of your nose (just below the bony bridge) firmly. Breathe through your mouth.",
                icon: "hand.draw.fill", illustrationIcon: "hand.point.up.left.fill", duration: 450),
            FirstAidStep(stepNumber: 3, title: "Apply Cold Compress",
                description: "Place a cold damp cloth on the bridge of the nose or back of the neck to help constrict blood vessels.",
                icon: "snowflake", illustrationIcon: "snowflake.circle.fill", duration: 90),
            FirstAidStep(stepNumber: 4, title: "Check & Rest",
                description: "After 10 minutes, gently release pressure. If still bleeding, repeat for another 10 minutes. Rest quietly afterwards.",
                icon: "clock.fill", illustrationIcon: "clock.badge.checkmark.fill", duration: nil),
            FirstAidStep(stepNumber: 5, title: "Avoid Triggers",
                description: "For the next few hours: do not blow your nose, bend down, lift heavy items, or use aspirin. Keep head elevated.",
                icon: "exclamationmark.triangle.fill", illustrationIcon: "nosign", duration: nil),
            FirstAidStep(stepNumber: 6, title: "Visit a Doctor",
                description: "See a healthcare professional if the nosebleed doesn't stop after 20 minutes, recurs frequently, or follows a head injury.",
                icon: "stethoscope", illustrationIcon: "stethoscope", duration: nil)
        ],
        warnings: ["Do not tilt the head back as it causes blood to drain into the throat", "Avoid blowing the nose immediately after bleeding stops", "Do not insert tissues deep into the nostril"],
        whenToSeekHelp: ["Bleeding doesn't stop after 20 minutes", "The nosebleed followed a head injury", "You're on blood thinners or have a clotting disorder", "Frequent recurrent nosebleeds"])

    static let normalGuide = FirstAidGuide(injuryType: .normal, title: "No Injury Detected", subtitle: "Stay prepared",
        steps: [FirstAidStep(stepNumber: 1, title: "Monitor for Changes",
            description: "If you develop symptoms later, use CurePath to scan and get guidance.",
            icon: "eye.fill", illustrationIcon: "eye.fill")],
        warnings: [], whenToSeekHelp: ["If you experience pain, swelling, or other symptoms"])
}
