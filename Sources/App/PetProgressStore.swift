import Foundation
import AgentBuddyCore

@MainActor
final class PetProgressStore: ObservableObject {
    static let shared = PetProgressStore()

    @Published private(set) var ledger: PetProgressLedger

    private static let defaultsKey = "agentbuddy.petProgressLedger"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.defaultsKey),
           let decoded = try? JSONDecoder().decode(PetProgressLedger.self, from: data) {
            ledger = decoded
        } else {
            ledger = PetProgressLedger()
        }
    }

    func progress(for petID: String?) -> PetProgress {
        ledger.progress(for: petID)
    }

    func isHatched(_ petID: String?) -> Bool {
        progress(for: petID).isHatched
    }

    @discardableResult
    func ingest(_ event: AgentEvent, selectedPetID: String? = PetController.shared.selectedPetID) -> PetProgressUpdate? {
        guard let tokenProgress = event.tokenProgress else { return nil }
        let key = "\(event.agentKind.rawValue):\(event.sessionId)"
        var updated = ledger
        guard let update = updated.ingest(tokenProgress, petID: selectedPetID, sessionKey: key) else { return nil }
        ledger = updated
        save()
        return update
    }

    private func save() {
        if let data = try? JSONEncoder().encode(ledger) {
            defaults.set(data, forKey: Self.defaultsKey)
        }
    }
}
