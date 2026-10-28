import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: GarageStore
    @AppStorage("mycar.language") private var language = "system"
    @AppStorage("mycar.textSize") private var textSize = "normal"
    @State private var isEditingCar = false

    var body: some View {
        Form {
            Section("Vehicle") {
                LabeledContent("Name", value: store.snapshot.car.name)
                if !store.snapshot.car.licensePlate.isEmpty {
                    LabeledContent("License plate", value: store.snapshot.car.licensePlate)
                }
                LabeledContent("Odometer", value: "\(store.snapshot.car.odometerKM.formatted()) km")
                Button("Edit vehicle") { isEditingCar = true }
            }
            Section("Vehicle photo") {
                if let photo = store.carPhoto {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 145)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .accessibilityLabel("Current car photo")
                }
                VehiclePhotoButton(store: store)
                if store.carPhoto != nil {
                    Button("Remove car photo", role: .destructive) {
                        store.removeCarPhoto()
                    }
                }
            }
            Section("Appearance") {
                Picker("Language", selection: $language) {
                    Text("System default").tag("system")
                    Text("Deutsch").tag("de")
                    Text("English").tag("en")
                }
                Picker("Text size", selection: $textSize) {
                    Text("Normal").tag("normal")
                    Text("Large").tag("large")
                    Text("Extra large").tag("extra")
                }
            }
            Section("Privacy") {
                Text("Vehicle data is stored locally and shared only with the MyCar widgets on this device.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isEditingCar) { VehicleEditorView(store: store) }
        .carPage()
    }
}

struct VehicleEditorView: View {
    @ObservedObject var store: GarageStore
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var manufacturer: String
    @State private var model: String
    @State private var plate: String
    @State private var year: String
    @State private var odometer: String

    init(store: GarageStore) {
        self.store = store
        let car = store.snapshot.car
        _name = State(initialValue: car.name)
        _manufacturer = State(initialValue: car.manufacturer)
        _model = State(initialValue: car.model)
        _plate = State(initialValue: car.licensePlate)
        _year = State(initialValue: car.year.map(String.init) ?? "")
        _odometer = State(initialValue: String(car.odometerKM))
    }

    private var valid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && (Int(odometer).map { $0 >= 0 } ?? false)
        && (year.isEmpty || (Int(year).map { (1886...2100).contains($0) } ?? false))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Your car") {
                    TextField("Nickname", text: $name)
                    TextField("Manufacturer", text: $manufacturer)
                    TextField("Model", text: $model)
                    TextField("License plate", text: $plate)
                    TextField("Model year (optional)", text: $year)
                        .keyboardType(.numberPad)
                    TextField("Odometer (km)", text: $odometer)
                        .keyboardType(.numberPad)
                }
                if !valid {
                    Text("Enter a name, valid mileage and optional model year.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .scrollContentBackground(.hidden)
            .background(CarTheme.background)
            .navigationTitle("Edit vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let car = CarProfile(
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            manufacturer: manufacturer.trimmingCharacters(in: .whitespacesAndNewlines),
                            model: model.trimmingCharacters(in: .whitespacesAndNewlines),
                            year: Int(year),
                            licensePlate: plate.trimmingCharacters(in: .whitespacesAndNewlines),
                            odometerKM: Int(odometer) ?? 0)
                        store.updateCar(car)
                        dismiss()
                    }
                    .disabled(!valid)
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}
