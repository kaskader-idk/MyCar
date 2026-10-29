import Foundation
import Combine
import WidgetKit
import UIKit

@MainActor
final class GarageStore: ObservableObject {
    @Published private(set) var archive: GarageArchive
    var snapshot: GarageSnapshot { archive.selected }
    var cars: [GarageSnapshot] { archive.cars }
    @Published private(set) var carPhoto: UIImage?

    init() {
        archive = GaragePersistence.loadArchive()
        // Seed shared storage even before the user edits anything.
        GaragePersistence.saveArchive(archive)
        WidgetCenter.shared.reloadAllTimelines()
        carPhoto = CarPhotoStorage.load(id: archive.selectedCarID)
    }

    /// Keeps the photo on the device, separate from the small widget JSON snapshot.
    @discardableResult
    func updateCarPhoto(from data: Data) -> Bool {
        guard let image = UIImage(data: data),
              let saved = CarPhotoStorage.save(image, id: archive.selectedCarID) else { return false }
        carPhoto = saved
        return true
    }

    func removeCarPhoto() {
        CarPhotoStorage.remove(id: archive.selectedCarID)
        carPhoto = nil
    }

    private func commit(_ change: (inout GarageSnapshot) -> Void) {
        var updated = archive
        guard let index = updated.cars.firstIndex(where: { $0.id == updated.selectedCarID }) else { return }
        change(&updated.cars[index])
        persist(updated)
    }

    private func persist(_ updated: GarageArchive) {
        archive = updated
        GaragePersistence.saveArchive(updated)
        WidgetCenter.shared.reloadAllTimelines()
    }

    func selectCar(_ id: UUID) {
        guard archive.cars.contains(where: { $0.id == id }) else { return }
        var updated = archive
        updated.selectedCarID = id
        persist(updated)
        carPhoto = CarPhotoStorage.load(id: id)
    }

    func nextCar(direction: Int) {
        guard let index = archive.cars.firstIndex(where: { $0.id == archive.selectedCarID }) else { return }
        let destination = index + direction
        guard archive.cars.indices.contains(destination) else { return }
        selectCar(archive.cars[destination].id)
    }

    func createCar(name: String) {
        var updated = archive
        var new = GarageSnapshot()
        new.car.name = name
        updated.cars.append(new)
        updated.selectedCarID = new.id
        persist(updated)
        carPhoto = nil
    }

    func deleteCurrentCar() {
        guard archive.cars.count > 1 else { return }
        let oldID = archive.selectedCarID
        var updated = archive
        updated.cars.removeAll(where: { $0.id == oldID })
        updated.selectedCarID = updated.cars[0].id
        persist(updated)
        CarPhotoStorage.remove(id: oldID)
        carPhoto = CarPhotoStorage.load(id: updated.selectedCarID)
    }

    func updateCar(_ car: CarProfile) {
        commit { $0.car = car }
    }

    func selectTireSet(_ id: UUID) {
        commit { snapshot in
            guard snapshot.tireSets.contains(where: { $0.id == id }) else { return }
            snapshot.activeTireSetID = id
        }
    }

    func createTireSet(name: String, season: TireSeason) {
        commit { snapshot in
            let set = TireSet(name: name, season: season)
            snapshot.tireSets.append(set)
            snapshot.activeTireSetID = set.id
        }
    }

    func updateTireSet(id: UUID, name: String, season: TireSeason) {
        commit { snapshot in
            guard let index = snapshot.tireSets.firstIndex(where: { $0.id == id }) else { return }
            snapshot.tireSets[index].name = name
            snapshot.tireSets[index].season = season
        }
    }

    func deleteTireSet(_ id: UUID) {
        commit { snapshot in
            guard snapshot.tireSets.count > 1 else { return }
            snapshot.tireSets.removeAll(where: { $0.id == id })
            if snapshot.activeTireSetID == id, let first = snapshot.tireSets.first {
                snapshot.activeTireSetID = first.id
            }
        }
    }

    func updateTire(_ tire: TireRecord, in setID: UUID) {
        commit { snapshot in
            guard let set = snapshot.tireSets.firstIndex(where: { $0.id == setID }) else { return }
            if let index = snapshot.tireSets[set].tires.firstIndex(where: { $0.position == tire.position }) {
                snapshot.tireSets[set].tires[index] = tire
            } else {
                snapshot.tireSets[set].tires.append(tire)
            }
        }
    }

    /// Quick +/- buttons in the four-wheel screen also persist immediately.
    func changeGrooveCount(position: TirePosition, setID: UUID, change: Int) {
        commit { snapshot in
            guard let set = snapshot.tireSets.firstIndex(where: { $0.id == setID }),
                  let wheel = snapshot.tireSets[set].tires.firstIndex(where: { $0.position == position }) else {
                return
            }
            var lanes = snapshot.tireSets[set].tires[wheel].lanes
            if change > 0 && lanes.count < 12 { lanes.append(TreadLane()) }
            if change < 0 && lanes.count > 1 { lanes.removeLast() }
            snapshot.tireSets[set].tires[wheel].lanes = lanes
        }
    }

    func upsertIssue(_ issue: CarIssue) {
        commit { snapshot in
            if let index = snapshot.issues.firstIndex(where: { $0.id == issue.id }) {
                snapshot.issues[index] = issue
            } else {
                snapshot.issues.append(issue)
            }
        }
    }

    func setIssueResolved(_ issue: CarIssue, resolved: Bool) {
        var updated = issue
        updated.isResolved = resolved
        updated.resolvedAt = resolved ? .now : nil
        upsertIssue(updated)
    }

    func deleteIssue(_ id: UUID) {
        commit { $0.issues.removeAll(where: { $0.id == id }) }
    }

    func updateService(_ service: ServiceReminder) {
        commit { $0.service = service }
    }
}

/// Separate image file to avoid putting large photos into UserDefaults / widget data.
private enum CarPhotoStorage {
    private static func imageURL(id: UUID) -> URL? {
        let manager = FileManager.default
        guard let root = manager.containerURL(forSecurityApplicationGroupIdentifier: GaragePersistence.appGroup)
            ?? manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return root.appendingPathComponent("MyCar", isDirectory: true)
            .appendingPathComponent("vehicle-\(id.uuidString).jpg")
    }

    static func load(id: UUID) -> UIImage? {
        guard let imageURL = imageURL(id: id),
              let data = try? Data(contentsOf: imageURL) else { return nil }
        return UIImage(data: data)
    }

    @discardableResult
    static func save(_ image: UIImage, id: UUID) -> UIImage? {
        guard let imageURL = imageURL(id: id) else { return nil }
        // Downsize imported photos to limit disk usage and dashboard memory use.
        let longest = max(image.size.width, image.size.height)
        guard longest > 0 else { return nil }
        let scale = min(1, 1600 / longest)
        let size = CGSize(width: max(1, image.size.width * scale),
                          height: max(1, image.size.height * scale))
        let renderer = UIGraphicsImageRenderer(size: size)
        let reduced = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let data = reduced.jpegData(compressionQuality: 0.82) else { return nil }
        do {
            try FileManager.default.createDirectory(at: imageURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try data.write(to: imageURL, options: .atomic)
            return reduced
        } catch {
            return nil
        }
    }

    static func remove(id: UUID) {
        guard let imageURL = imageURL(id: id) else { return }
        try? FileManager.default.removeItem(at: imageURL)
    }
}
