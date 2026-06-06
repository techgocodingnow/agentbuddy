import SwiftUI
import AppKit

/// A searchable gallery to download new pets into the app.
struct BrowsePetsView: View {
    @StateObject private var browser = PetBrowser()
    @State private var previewPet: RemotePet?
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
        .sheet(item: $previewPet) { pet in
            RemotePetPreviewSheet(pet: pet, browser: browser)
        }
    }

    @ViewBuilder private var content: some View {
        if browser.isLoading && browser.pets.isEmpty {
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
                        RemotePetRow(pet: pet, browser: browser) {
                            previewPet = pet
                        }
                        Divider()
                    }
                    if browser.isLoading {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Loading more pets…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                }
            }
        }
    }
}

private struct RemotePetRow: View {
    let pet: RemotePet
    @ObservedObject var browser: PetBrowser
    let onPreview: () -> Void

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

            HStack(spacing: 8) {
                Button {
                    onPreview()
                } label: {
                    Label("Preview", systemImage: "play.circle")
                }
                .controlSize(.small)

                if browser.downloading.contains(pet.id) {
                    ProgressView().controlSize(.small)
                } else if browser.installed.contains(pet.id) {
                    Label("Added", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                } else {
                    Button {
                        browser.download(pet)
                    } label: {
                        Label("Get", systemImage: "arrow.down.circle")
                    }
                    .controlSize(.small)
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
    }
}

private struct RemotePetPreviewSheet: View {
    let pet: RemotePet
    @ObservedObject var browser: PetBrowser
    @Environment(\.dismiss) private var dismiss
    @State private var clips: [[NSImage]]?
    @State private var errorText: String?
    @State private var selectedClip = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(pet.name)
                        .font(.headline)
                    Text("by \(pet.author)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(16)

            previewContent
                .frame(maxWidth: .infinity, minHeight: 240)
                .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
                .padding(.horizontal, 16)

            HStack(spacing: 10) {
                clipPicker

                Spacer()

                if browser.downloading.contains(pet.id) {
                    ProgressView()
                        .controlSize(.small)
                } else if browser.installed.contains(pet.id) {
                    Label("Added", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                } else {
                    Button {
                        browser.download(pet)
                    } label: {
                        Label("Get", systemImage: "arrow.down.circle")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(16)
        }
        .frame(width: 360)
        .preferredColorScheme(.dark)
        .task(id: pet.id) {
            await loadPreview()
        }
    }

    @ViewBuilder private var previewContent: some View {
        if let clips, !clips.isEmpty {
            ImageSpriteView(frames: clips[safe: selectedClip] ?? clips[0], mood: .working, size: 180)
                .padding(.vertical, 20)
        } else if let errorText {
            VStack(spacing: 8) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text(errorText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        } else {
            VStack(spacing: 10) {
                ProgressView()
                Text("Loading preview...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var clipPicker: some View {
        if let clips, clips.count > 1 {
            Picker("Animation", selection: $selectedClip) {
                ForEach(clips.indices, id: \.self) { index in
                    Text("Clip \(index + 1)").tag(index)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(width: 120)
        }
    }

    private func loadPreview() async {
        clips = nil
        errorText = nil
        selectedClip = 0

        guard let sheetURL = URL(string: pet.spritesheetUrl) else {
            errorText = "This pet does not have a valid spritesheet."
            return
        }

        do {
            let data = try await PetdexAssets.data(sheetURL)
            guard let nsImage = NSImage(data: data) else { throw PreviewLoadError() }
            var rect = CGRect(origin: .zero, size: nsImage.size)
            guard let cgImage = nsImage.cgImage(forProposedRect: &rect, context: nil, hints: nil) else {
                throw PreviewLoadError()
            }

            let sliced = SpriteSlicer.slice(cgImage).map { row in
                row.map { NSImage(cgImage: $0, size: NSSize(width: $0.width, height: $0.height)) }
            }
            guard !sliced.isEmpty else { throw PreviewLoadError() }
            clips = sliced
        } catch {
            errorText = "Couldn't load this animation preview."
        }
    }
}

private struct PreviewLoadError: Error {}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
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
