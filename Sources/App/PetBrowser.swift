import Foundation
import AgentBuddyCore

private enum RemotePetSource {
    case openPets
    case codexPets

    var label: String {
        switch self {
        case .openPets: return "OpenPets"
        case .codexPets: return "Codex Pets"
        }
    }
}

struct RemotePet: Decodable, Identifiable {
    let slug: String
    let displayName: String?
    let description: String?
    let kind: String?
    let submittedBy: String?
    let thumbnailUrl: String?
    let spritesheetUrl: String
    let petJsonUrl: String?
    let featured: Bool
    let original: Bool
    private let source: RemotePetSource

    var id: String {
        switch source {
        case .openPets: return slug
        case .codexPets: return "codex-pets-\(slug)"
        }
    }
    var name: String { displayName ?? slug }
    var author: String { submittedBy ?? source.label }
    var isCodexPets: Bool { source == .codexPets }

    enum CodingKeys: String, CodingKey {
        case id, slug, displayName, description, kind, category, submittedBy, ownerName
        case thumbnail, thumbnailUrl, posterUrl, previewUrl, spritesheet, spritesheetUrl
        case petJsonUrl, downloadUrl, featured, original
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let ownerName = try container.decodeIfPresent(String.self, forKey: .ownerName)
        let downloadUrl = try container.decodeIfPresent(String.self, forKey: .downloadUrl)
        slug = try container.decodeIfPresent(String.self, forKey: .slug)
            ?? container.decode(String.self, forKey: .id)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        kind = try container.decodeIfPresent(String.self, forKey: .kind)
            ?? container.decodeIfPresent(String.self, forKey: .category)
        submittedBy = try container.decodeIfPresent(String.self, forKey: .submittedBy) ?? ownerName
        thumbnailUrl = try container.decodeIfPresent(String.self, forKey: .thumbnailUrl)
            ?? container.decodeIfPresent(String.self, forKey: .thumbnail)
            ?? container.decodeIfPresent(String.self, forKey: .posterUrl)
            ?? container.decodeIfPresent(String.self, forKey: .previewUrl)
        spritesheetUrl = try container.decodeIfPresent(String.self, forKey: .spritesheetUrl)
            ?? container.decode(String.self, forKey: .spritesheet)
        petJsonUrl = try container.decodeIfPresent(String.self, forKey: .petJsonUrl)
        featured = try container.decodeIfPresent(Bool.self, forKey: .featured) ?? false
        original = try container.decodeIfPresent(Bool.self, forKey: .original) ?? false
        source = ownerName == nil && downloadUrl == nil ? .openPets : .codexPets
    }

    var previewUrlString: String {
        thumbnailUrl ?? petdexThumbnailURL(slug: slug)?.absoluteString ?? spritesheetUrl
    }

    private func petdexThumbnailURL(slug: String) -> URL? {
        guard slug.range(of: #"^[a-z0-9][a-z0-9-]{0,62}$"#, options: .regularExpression) != nil else {
            return nil
        }
        return URL(string: "https://petdex.crafter.run/api/pets/\(slug)/thumb")
    }
}

/// Decodes `T` but tolerates a malformed element (yields `nil` instead of
/// failing the whole array).
private struct Lenient<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) {
        value = try? T(from: decoder)
    }
}

/// Loads the online pet library and downloads packs into `~/.agentbuddy/pets/`.
@MainActor
final class PetBrowser: ObservableObject {
    @Published var pets: [RemotePet] = []
    @Published var isLoading = false
    @Published var errorText: String?
    @Published var query = ""
    @Published var category = "all"
    @Published var downloading: Set<String> = []
    @Published var installed: Set<String> = []
    /// A transient per-download failure, shown without hiding the pet list.
    @Published var downloadError: String?

    static let categories: [(label: String, value: String)] = [
        ("All", "all"), ("Featured", "featured"), ("Originals", "original"),
        ("Western", "western"), ("Asian", "asian"), ("Codex Pets", "codex-pets"),
    ]

    // OpenPets publishes the gallery as a static catalog with paged entries.
    private static let catalogURL = URL(string: "https://openpets.dev/pets/catalog.v3.json")!
    private static let codexPetsPageSize = 60

    private struct Catalog: Decodable {
        let pages: [URL]
    }

    private struct PageLoadError: Error {}

    private struct Page: Decodable {
        let pets: [RemotePet]
        let totalPages: Int?
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            pets = try container.decode([Lenient<RemotePet>].self, forKey: .pets).compactMap(\.value)
            totalPages = try container.decodeIfPresent(Int.self, forKey: .totalPages)
        }
        enum CodingKeys: String, CodingKey { case pets, totalPages }
    }
    var results: [RemotePet] {
        var list = pets
        if category == "featured" {
            list = list.filter(\.featured)
        } else if category == "original" {
            list = list.filter(\.original)
        } else if category == "codex-pets" {
            list = list.filter(\.isCodexPets)
        } else if category != "all" {
            list = list.filter { $0.kind == category }
        }
        guard !query.isEmpty else { return list }
        let q = query.lowercased()
        return list.filter { $0.name.lowercased().contains(q) || $0.slug.contains(q) }
    }

    func loadIfNeeded() {
        // Mark pets already on disk as added.
        installed = Set(ImagePetStore.shared.packs.map(\.id))
        guard pets.isEmpty, !isLoading else { return }
        isLoading = true
        errorText = nil
        Task {
            do {
                var pets: [RemotePet] = []
                var lastError: Error?

                do { pets.append(contentsOf: try await Self.loadOpenPets()) }
                catch { lastError = error }

                do { pets.append(contentsOf: try await Self.loadCodexPets()) }
                catch { lastError = error }

                guard !pets.isEmpty else { throw lastError ?? PageLoadError() }
                self.pets = pets
            } catch {
                self.errorText = "Couldn't load the pet library. Check your connection."
            }
            self.isLoading = false
        }
    }

    func download(_ pet: RemotePet) {
        guard !downloading.contains(pet.id) else { return }
        downloadError = nil
        downloading.insert(pet.id)
        Task {
            await performDownload(pet)
            self.downloading.remove(pet.id)
        }
    }

    private func performDownload(_ pet: RemotePet) async {
        guard let sheetURL = URL(string: pet.spritesheetUrl) else { return }

        do {
            let id: String
            if let petJsonUrl = pet.petJsonUrl, let petJsonURL = URL(string: petJsonUrl) {
                id = try await PetInstaller.download(slug: pet.id, petJsonURL: petJsonURL, spritesheetURL: sheetURL)
            } else {
                id = try await PetInstaller.download(slug: pet.id,
                                                     displayName: pet.name,
                                                     description: pet.description,
                                                     spritesheetURL: sheetURL)
            }
            ImagePetStore.shared.reload()
            installed.insert(id)
            PetController.shared.selectedPetID = id
            downloadError = nil
        } catch {
            downloadError = PetInstaller.message(for: error, pet: pet.name)
        }
    }

    private static func loadOpenPets() async throws -> [RemotePet] {
        let catalogData = try await PetdexAssets.data(catalogURL)
        let catalog = try JSONDecoder().decode(Catalog.self, from: catalogData)
        var pets: [RemotePet] = []
        for pageURL in catalog.pages {
            let pageData = try await PetdexAssets.data(pageURL)
            pets.append(contentsOf: try JSONDecoder().decode(Page.self, from: pageData).pets)
        }
        return pets
    }

    private static func loadCodexPets() async throws -> [RemotePet] {
        let firstPageData = try await PetdexAssets.data(codexPetsURL(page: 1))
        let firstPage = try JSONDecoder().decode(Page.self, from: firstPageData)
        var pets = firstPage.pets

        let totalPages = firstPage.totalPages ?? 1
        guard totalPages > 1 else { return pets }

        for page in 2...totalPages {
            let pageData = try await PetdexAssets.data(codexPetsURL(page: page))
            pets.append(contentsOf: try JSONDecoder().decode(Page.self, from: pageData).pets)
        }
        return pets
    }

    private static func codexPetsURL(page: Int) -> URL {
        var components = URLComponents(string: "https://codex-pets.net/api/pets")!
        components.queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "pageSize", value: String(codexPetsPageSize)),
            URLQueryItem(name: "content", value: "all"),
        ]
        return components.url!
    }
}
