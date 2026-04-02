import Foundation
import UIKit
import Combine

class InjuryDataManager: ObservableObject {
    static let shared = InjuryDataManager()
    @Published var injuries: [InjuryRecord] = []

    private let userDefaultsKey = "savedInjuries"
    private let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

    init() { loadInjuries() }

    func saveInjury(type: InjuryType, image: UIImage, confidence: Float, location: String = "Unspecified",
                    woundScore: Double = 0, boundingBoxArea: Double = 0, woundPixelDensity: Double = 0, woundRegion: CGRect? = nil) {
        let imagePath = saveImageToDisk(image)
        let days = estimatedRecoveryDays(for: type)
        let baseline = DailyCheckIn(id: UUID(), date: Date(), imagePath: imagePath,
                                    boundingBoxArea: boundingBoxArea, woundPixelDensity: woundPixelDensity,
                                    woundScore: woundScore, deltaScore: nil, trend: .baseline)
        let record = InjuryRecord(id: UUID(), title: "\(location) \(type.rawValue)", type: type,
                                  date: Date(), currentDay: 0, totalDays: days, isActive: true,
                                  confidence: confidence, imagePath: imagePath,
                                  checkIns: [baseline], consecutiveStableDays: 0, needsDoctorSuggestion: false)
        injuries.insert(record, at: 0)
        persist()
    }
    func addCheckIn(_ checkIn: DailyCheckIn, to injuryID: UUID, forDay: Int? = nil) {
        guard let idx = injuries.firstIndex(where: { $0.id == injuryID }) else { return }
        var updated = injuries[idx]
        updated.checkIns.append(checkIn)

        let targetDay = forDay ?? (updated.currentDay + 1)
        updated.currentDay = max(updated.currentDay + 1, min(targetDay, updated.totalDays))
        updated.isActive   = updated.currentDay < updated.totalDays

        let stableDays = WoundProgressService.updateConsecutiveStableDays(checkIns: updated.checkIns)
        updated.consecutiveStableDays = stableDays

        let daysSinceStart = Calendar.current.dateComponents([.day], from: updated.date, to: Date()).day ?? 0
        let healingCount   = updated.checkIns.filter { $0.trend == .healing }.count

        if stableDays >= 4 || (daysSinceStart >= 5 && updated.checkIns.count >= 2 && healingCount == 0) {
            updated.needsDoctorSuggestion = true
        }
        injuries[idx] = updated
        persist()
    }

    func deleteInjury(_ injury: InjuryRecord) {
        try? FileManager.default.removeItem(at: documentsDirectory.appendingPathComponent(injury.imagePath))
        for ci in injury.checkIns {
            try? FileManager.default.removeItem(at: documentsDirectory.appendingPathComponent(ci.imagePath))
        }
        injuries.removeAll { $0.id == injury.id }
        persist()
    }

    func loadImage(filename: String) -> UIImage? {
        guard let data = try? Data(contentsOf: documentsDirectory.appendingPathComponent(filename)) else { return nil }
        return UIImage(data: data)
    }

    private func saveImageToDisk(_ image: UIImage) -> String {
        let filename = UUID().uuidString + ".jpg"
        let url = documentsDirectory.appendingPathComponent(filename)
        if let data = image.jpegData(compressionQuality: 0.8) { try? data.write(to: url) }
        return filename
    }

    private func loadInjuries() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode([InjuryRecord].self, from: data)
        else { injuries = []; return }
        injuries = decoded
    }

    private func persist() {
        if let encoded = try? JSONEncoder().encode(injuries) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }

    private func estimatedRecoveryDays(for type: InjuryType) -> Int {
        switch type {
        case .cut:        return 7
        case .burn:       return 14
        case .abrasion:   return 10
        case .laceration: return 10
        case .venomBite:  return 7
        case .sprain:     return 14
        case .nosebleed:  return 3
        case .normal, .unknown: return 0
        }
    }
}
