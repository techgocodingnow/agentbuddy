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
    static let defaultPetID = "super-piglet"
    private static let installedKey = "agentbuddy.bundledDefaultPetInstalled"

    @discardableResult
    static func installIfNeeded() -> Bool {
        let petsDirectory = URL(fileURLWithPath: AgentBuddyPaths.baseDir).appendingPathComponent("pets")
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: installedKey) else { return false }

        let installed = installIfNeeded(
            sourceDirectory: Bundle.module.url(forResource: defaultPetID, withExtension: nil),
            petsDirectory: petsDirectory
        )
        if installed || hasInstalledDefault(in: petsDirectory, fileManager: .default) {
            defaults.set(true, forKey: installedKey)
        }
        return installed
    }

    @discardableResult
    static func installIfNeeded(sourceDirectory: URL?,
                                petsDirectory: URL,
                                fileManager: FileManager = .default) -> Bool {
        guard let sourceDirectory else { return false }

        let destination = petsDirectory.appendingPathComponent(defaultPetID)
        if hasInstalledDefault(in: petsDirectory, fileManager: fileManager) {
            return false
        }

        do {
            try fileManager.createDirectory(at: petsDirectory, withIntermediateDirectories: true)
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: sourceDirectory, to: destination)
            return true
        } catch {
            return false
        }
    }

    private static func hasInstalledDefault(in petsDirectory: URL,
                                            fileManager: FileManager) -> Bool {
        let destination = petsDirectory.appendingPathComponent(defaultPetID)
        let manifest = destination.appendingPathComponent("pet.json")
        let spritesheet = destination.appendingPathComponent("spritesheet.webp")
        return fileManager.fileExists(atPath: manifest.path)
            && fileManager.fileExists(atPath: spritesheet.path)
    }
}
