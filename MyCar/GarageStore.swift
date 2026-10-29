import Foundation
import Combine
import WidgetKit
import UIKit

@MainActor
final class GarageStore: ObservableObject {
    @Published private(set) var snapshot: GarageSnapshot
    @Published private(set) var carPhoto: UIImage?

    init() {
        snapshot = GaragePersistence.load()
        carPhoto = CarPhotoStorage.load()
    }

    /// Keeps the photo on the device, separate from the small widget JSON snapshot.
    @discardableResult
    func updateCarPhoto(from data: Data) -> Bool {
        guard let image = UIImage(data: data),
              let saved = CarPhotoStorage.save(image) else { return false }
        carPhoto = saved
        return true
    }

    func removeCarPhoto() {
        CarPhotoStorage.remove()
        carPhoto = nil
    }

    private func commit(_ change: (inout GarageSnapshot) -> Void) {
        var updated = snapshot
        change(&updated)
        snapshot = updated
        GaragePersistence.save(updated)
        WidgetCenter.shared.reloadAllTimelines()
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
    private static var imageURL: URL? {
        let manager = FileManager.default
        guard let root = manager.containerURL(forSecurityApplicationGroupIdentifier: GaragePersistence.appGroup)
            ?? manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return root.appendingPathComponent("MyCar", isDirectory: true)
            .appendingPathComponent("vehicle-photo.jpg")
    }

    static func load() -> UIImage? {
        guard let imageURL,
              let data = try? Data(contentsOf: imageURL) else { return nil }
        return UIImage(data: data)
    }

    @discardableResult
    static func save(_ image: UIImage) -> UIImage? {
        guard let imageURL else { return nil }
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

    static func remove() {
        guard let imageURL else { return }
        try? FileManager.default.removeItem(at: imageURL)
    }
}
