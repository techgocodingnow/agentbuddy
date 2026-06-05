import Foundation
import AgentBuddyCore

enum PetdexError: Error {
    case badStatus(Int)
}

/// Petdex's asset CDN expects requests to identify Petdex as the source page.
enum PetdexAssets {
    static func request(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        if url.host == "petdex.crafter.run" {
            request.setValue("https://petdex.crafter.run/", forHTTPHeaderField: "Referer")
        }
        return request
    }

    /// Fetches an asset with retries for transient Petdex/CDN failures.
    static func data(_ url: URL) async throws -> Data {
        var lastStatus = 0

        for attempt in 0..<3 {
            let (data, response) = try await URLSession.shared.data(for: request(url))
            let status = (response as? HTTPURLResponse)?.statusCode ?? 200
            if (200..<300).contains(status) {
                return data
            }

            lastStatus = status
            guard (status == 429 || status >= 500), attempt < 2 else {
                break
            }

            try await Task.sleep(nanoseconds: UInt64(attempt + 1) * 900_000_000)
        }

        throw PetdexError.badStatus(lastStatus)
    }
}

/// Downloads a pet pack (pet.json + spritesheet) into `~/.agentbuddy/pets/<slug>/`.
/// Shared by the Browse gallery and first-run onboarding.
enum PetInstaller {
    private struct PackMeta: Decodable { let id: String?; let spritesheetPath: String }
    private struct GeneratedPackMeta: Encodable {
        let id: String
        let displayName: String
        let description: String?
        let spritesheetPath: String
    }

    /// Returns the installed pack's id (pet.json `id`); throws on failure.
    @discardableResult
    static func download(slug: String, petJsonURL: URL, spritesheetURL: URL) async throws -> String {
        let fm = FileManager.default
        let dir = URL(fileURLWithPath: AgentBuddyPaths.baseDir)
            .appendingPathComponent("pets").appendingPathComponent(slug)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)

        let petJsonData = try await PetdexAssets.data(petJsonURL)
        let meta = try JSONDecoder().decode(PackMeta.self, from: petJsonData)
        try petJsonData.write(to: dir.appendingPathComponent("pet.json"))

        let sheetData = try await PetdexAssets.data(spritesheetURL)
        try sheetData.write(to: dir.appendingPathComponent(meta.spritesheetPath))

        return meta.id ?? slug
    }

    /// Installs a gallery entry that provides metadata plus a spritesheet URL.
    @discardableResult
    static func download(slug: String, displayName: String, description: String?, spritesheetURL: URL) async throws -> String {
        let fm = FileManager.default
        let dir = URL(fileURLWithPath: AgentBuddyPaths.baseDir)
            .appendingPathComponent("pets").appendingPathComponent(slug)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)

        let spritesheetPath = spritesheetURL.lastPathComponent.isEmpty ? "spritesheet.webp" : spritesheetURL.lastPathComponent
        let meta = GeneratedPackMeta(id: slug,
                                     displayName: displayName,
                                     description: description,
                                     spritesheetPath: spritesheetPath)
        try JSONEncoder().encode(meta).write(to: dir.appendingPathComponent("pet.json"))

        let sheetData = try await PetdexAssets.data(spritesheetURL)
        try sheetData.write(to: dir.appendingPathComponent(spritesheetPath))

        return slug
    }

    static func message(for error: Error, pet: String) -> String {
        if case PetdexError.badStatus(let status) = error, status == 429 {
            return "Petdex is rate-limiting downloads right now. Wait a moment and tap Get again."
        }

        return "Couldn't download \(pet). Check your connection and try again."
    }
}

/// Installs a starter pet on the very first launch so the app isn't empty.
@MainActor
enum DefaultPetBootstrap {
    private static let triedKey = "agentbuddy.defaultPetTried"
    private static let catalogPageURL = URL(string: "https://openpets.dev/pets/catalog.v3/page-000.json")!
    /// Preferred starter (a non-franchise original); falls back to any pet.
    private static let preferredSlug = "boba"

    struct Entry: Decodable {
        let slug: String
        let displayName: String?
        let description: String?
        let spritesheetUrl: String

        enum CodingKeys: String, CodingKey {
            case id, slug, displayName, description, spritesheet, spritesheetUrl
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            slug = try container.decodeIfPresent(String.self, forKey: .slug)
                ?? container.decode(String.self, forKey: .id)
            displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
            description = try container.decodeIfPresent(String.self, forKey: .description)
            spritesheetUrl = try container.decodeIfPresent(String.self, forKey: .spritesheetUrl)
                ?? container.decode(String.self, forKey: .spritesheet)
        }
    }
    private struct Page: Decodable { let pets: [Lenient<Entry>] }

    static func installIfNeeded() {
        let d = UserDefaults.standard
        guard !d.bool(forKey: triedKey) else { return }
        guard ImagePetStore.shared.packs.isEmpty, PetController.shared.selectedPetID == nil else {
            d.set(true, forKey: triedKey)
            return
        }
        d.set(true, forKey: triedKey)   // attempt once, even if offline

        Task {
            guard let data = try? await PetdexAssets.data(catalogPageURL),
                  let page = try? JSONDecoder().decode(Page.self, from: data) else { return }
            let pets = page.pets.compactMap(\.value)
            let pick = pets.first { $0.slug == preferredSlug } ?? pets.first
            guard let pick,
                  let sheetURL = URL(string: pick.spritesheetUrl) else { return }

            let id = try? await PetInstaller.download(slug: pick.slug,
                                                       displayName: pick.displayName ?? pick.slug,
                                                       description: pick.description,
                                                       spritesheetURL: sheetURL)
            ImagePetStore.shared.reload()
            if let id, PetController.shared.selectedPetID == nil {
                PetController.shared.selectedPetID = id
            }
        }
    }
}

/// Tolerant decode wrapper: a malformed element yields nil instead of failing.
private struct Lenient<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) { value = try? T(from: decoder) }
}
