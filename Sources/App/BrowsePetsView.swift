import SwiftUI
import AppKit

/// A searchable gallery to download new pets into the app.
struct BrowsePetsView: View {
    @StateObject private var browser = PetBrowser()
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Browse pets").font(.headline)
                Spacer()
                Button("Done") { onClose() }
            }
            .padding(12)
            Divider()

            NativeSearchField(text: $browser.query, placeholder: "Search pets")
                .padding(.horizontal, 12).padding(.top, 12)

            Picker("Category", selection: $browser.category) {
                ForEach(PetBrowser.categories, id: \.value) { Text($0.label).tag($0.value) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 12).padding(.vertical, 8)

            if let downloadError = browser.downloadError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(downloadError)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        browser.downloadError = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color.orange.opacity(0.12))
            }

            content
        }
        .frame(width: 460, height: 580)
        .preferredColorScheme(.dark)
        .noFocusRing()
        .onAppear { browser.loadIfNeeded() }
    }

    @ViewBuilder private var content: some View {
        if browser.isLoading {
            VStack(spacing: 10) {
                ProgressView()
                Text("Loading pets…").font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = browser.errorText {
            VStack(spacing: 10) {
                Image(systemName: "wifi.exclamationmark").font(.largeTitle).foregroundStyle(.secondary)
                Text(error).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button("Retry") { browser.loadIfNeeded() }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(browser.results) { pet in
                        RemotePetRow(pet: pet, browser: browser)
                        Divider()
                    }
                }
            }
        }
    }
}

private struct RemotePetRow: View {
    let pet: RemotePet
    @ObservedObject var browser: PetBrowser

    var body: some View {
        HStack(spacing: 12) {
            FirstFrameThumb(urlString: pet.previewUrlString)
                .frame(width: 44, height: 48)
                .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))

            VStack(alignment: .leading, spacing: 2) {
                Text(pet.name).font(.system(size: 13, weight: .medium))
                Text("by \(pet.author)").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()

            if browser.downloading.contains(pet.id) {
                ProgressView().controlSize(.small)
            } else if browser.installed.contains(pet.id) {
                Label("Added", systemImage: "checkmark.circle.fill").foregroundStyle(.green).font(.caption)
            } else {
                Button("Get") { browser.download(pet) }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
    }
}

/// Shows Petdex's pre-rendered first-frame thumbnail, loaded on demand.
private struct FirstFrameThumb: View {
    let urlString: String
    @State private var image: NSImage?
    @State private var failed = false

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .padding(3)
            } else if failed {
                Image(systemName: "pawprint").foregroundStyle(.secondary)
            } else {
                ProgressView().controlSize(.small)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .task(id: urlString) {
            image = nil
            failed = false
            guard let url = URL(string: urlString) else {
                failed = true
                return
            }

            if let loadedImage = await ThumbLoader.shared.image(for: url) {
                image = loadedImage
            } else {
                failed = true
            }
        }
    }
}

/// Loads and caches Browse-pets thumbnails without bursting one request per row.
@MainActor
private final class ThumbLoader {
    static let shared = ThumbLoader()

    private let cache = NSCache<NSURL, NSImage>()
    private var active = 0

    func image(for url: URL) async -> NSImage? {
        let key = url as NSURL
        if let cached = cache.object(forKey: key) {
            return cached
        }

        while active >= 3 {
            try? await Task.sleep(nanoseconds: 120_000_000)
        }
        if let cached = cache.object(forKey: key) {
            return cached
        }

        active += 1
        defer { active -= 1 }

        guard let data = try? await PetdexAssets.data(url),
              let image = NSImage(data: data) else {
            return nil
        }

        cache.setObject(image, forKey: key)
        return image
    }
}
