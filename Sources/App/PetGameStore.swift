import Foundation
import AgentBuddyCore

@MainActor
final class PetGameStore: ObservableObject {
    static let shared = PetGameStore()

    @Published private(set) var ledger: PetGameLedger

    private static let defaultsKey = "agentbuddy.petGameLedger"
    private let defaults: UserDefaults
    private let calendar: Calendar

    init(
        defaults: UserDefaults = .standard,
        progressLedger: PetProgressLedger? = nil,
        calendar: Calendar = .current,
        now: Date = Date()
    ) {
        self.defaults = defaults
        self.calendar = calendar
        if let data = defaults.data(forKey: Self.defaultsKey),
           let decoded = try? JSONDecoder().decode(PetGameLedger.self, from: data) {
            ledger = decoded
        } else {
            var bootstrapped = PetGameLedger()
            PetGameEngine.syncExistingProgress(
                progressLedger: progressLedger ?? PetProgressStore.shared.ledger,
                into: &bootstrapped,
                today: now,
                calendar: calendar
            )
            ledger = bootstrapped
            save()
        }
    }

    func profile(for petID: String?) -> PetGameProfile {
        ledger.profile(for: petID, calendar: calendar)
    }

    func equippedCosmeticID(for petID: String?) -> String? {
        profile(for: petID).equippedCosmeticID
    }

    func unlockedCosmetics(for petID: String?) -> [PetCosmetic] {
        let profile = profile(for: petID)
        return PetGameRules.cosmetics.filter { profile.unlockedCosmeticIDs.contains($0.id) }
    }

    func setEquippedCosmeticID(_ cosmeticID: String?, for petID: String?) {
        guard let petID, !petID.isEmpty else { return }
        var profile = ledger.profile(for: petID, calendar: calendar)
        if let cosmeticID, !profile.unlockedCosmeticIDs.contains(cosmeticID) {
            return
        }
        profile.equippedCosmeticID = cosmeticID
        ledger.setProfile(profile, for: petID)
        save()
    }

    @discardableResult
    func ingest(
        event: AgentEvent,
        progressUpdate: PetProgressUpdate?,
        selectedPetID: String? = PetController.shared.selectedPetID,
        now: Date = Date()
    ) -> PetGameUpdate? {
        var updated = ledger
        let gameUpdate = PetGameEngine.ingest(
            event: event,
            progressUpdate: progressUpdate,
            selectedPetID: selectedPetID,
            into: &updated,
            now: now,
            calendar: calendar
        )
        ledger = updated
        save()
        return gameUpdate
    }

    private func save() {
        if let data = try? JSONEncoder().encode(ledger) {
            defaults.set(data, forKey: Self.defaultsKey)
        }
    }
}
