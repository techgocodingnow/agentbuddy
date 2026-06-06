import XCTest
@testable import agentbuddy

@MainActor
final class DefaultPetBootstrapTests: XCTestCase {
    func testInstallsBundledDefaultPetIntoPetsDirectory() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("agentbuddy-default-pet-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("source")
        let pets = root.appendingPathComponent("pets")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        let manifest = Data(#"{"id":"super-piglet","displayName":"Super Piglet","spritesheetPath":"spritesheet.webp"}"#.utf8)
        try manifest.write(to: source.appendingPathComponent("pet.json"))
        try Data([0x52, 0x49, 0x46, 0x46]).write(to: source.appendingPathComponent("spritesheet.webp"))

        XCTAssertTrue(DefaultPetBootstrap.installIfNeeded(sourceDirectory: source, petsDirectory: pets))

        let installed = pets.appendingPathComponent(DefaultPetBootstrap.defaultPetID)
        XCTAssertTrue(FileManager.default.fileExists(atPath: installed.appendingPathComponent("pet.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: installed.appendingPathComponent("spritesheet.webp").path))
    }

    func testDoesNotOverwriteExistingDefaultPet() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("agentbuddy-default-pet-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("source")
        let pets = root.appendingPathComponent("pets")
        let installed = pets.appendingPathComponent(DefaultPetBootstrap.defaultPetID)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: installed, withIntermediateDirectories: true)
        try "source".write(to: source.appendingPathComponent("pet.json"), atomically: true, encoding: .utf8)
        try Data([1]).write(to: source.appendingPathComponent("spritesheet.webp"))
        try "existing".write(to: installed.appendingPathComponent("pet.json"), atomically: true, encoding: .utf8)
        try Data([2]).write(to: installed.appendingPathComponent("spritesheet.webp"))

        XCTAssertFalse(DefaultPetBootstrap.installIfNeeded(sourceDirectory: source, petsDirectory: pets))
        XCTAssertEqual(
            try String(contentsOf: installed.appendingPathComponent("pet.json"), encoding: .utf8),
            "existing"
        )
    }
}
