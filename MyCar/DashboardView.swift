import SwiftUI
import PhotosUI

struct DashboardView: View {
    @ObservedObject var store: GarageStore
    @State private var editingCar = false

    private var car: CarProfile { store.snapshot.car }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MYCAR")
                            .tracking(3)
                            .font(.caption.bold())
                            .foregroundStyle(CarTheme.accent)
                        Text("My garage")
                            .font(.largeTitle.bold())
                    }
                    Spacer()
                    NavigationLink { SettingsView(store: store) } label: {
                        Image(systemName: "gearshape")
                            .font(.title3)
                            .frame(width: 43, height: 43)
                            .background(CarTheme.raised, in: Circle())
                    }
                    .accessibilityLabel("Settings")
                }

                carPhoto

                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(car.name)
                                .font(.title.bold())
                            Text([car.manufacturer, car.model, car.year.map(String.init) ?? ""]
                                .filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(.subheadline)
                                .foregroundStyle(CarTheme.muted)
                        }
                        Spacer(minLength: 5)
                        Button {
                            editingCar = true
                        } label: {
                            Image(systemName: "square.and.pencil")
                                .font(.title3)
                                .padding(10)
                                .background(CarTheme.raised, in: RoundedRectangle(cornerRadius: 13))
                        }
                        .accessibilityLabel("Edit vehicle")
                    }

                    Divider().overlay(CarTheme.raised)

                    VStack(alignment: .leading, spacing: 5) {
                        Text("VIN")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(CarTheme.muted)
                        Text(car.vin.flatMap { $0.isEmpty ? nil : $0 } ?? "Not entered")
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                    }

                    HStack(alignment: .firstTextBaseline) {
                        Text("Odometer")
                            .foregroundStyle(CarTheme.muted)
                        Spacer()
                        Text("\(car.odometerKM.formatted()) km")
                            .font(.headline.monospacedDigit())
                    }

                    if !car.licensePlate.isEmpty {
                        HStack {
                            Text("License plate")
                                .foregroundStyle(CarTheme.muted)
                            Spacer()
                            Text(car.licensePlate)
                                .fontWeight(.semibold)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Car details")
                            .font(.headline)
                        if let details = car.details, !details.isEmpty {
                            Text(details)
                                .foregroundStyle(CarTheme.muted)
                        } else {
                            Text("Add vehicle details in My Car.")
                                .foregroundStyle(CarTheme.muted)
                        }
                    }
                }
                .padding(20)
                .background(CarTheme.surface, in: RoundedRectangle(cornerRadius: 23))

                NavigationLink { ServiceView(store: store) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "wrench.adjustable.fill")
                            .foregroundStyle(CarTheme.accent)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Next service").font(.headline)
                            if let due = store.snapshot.service.dueDate {
                                Text(due, format: .dateTime.day().month().year())
                                    .font(.caption).foregroundStyle(CarTheme.muted)
                            } else if let km = store.snapshot.service.dueOdometerKM {
                                Text("\(km.formatted()) km")
                                    .font(.caption).foregroundStyle(CarTheme.muted)
                            } else {
                                Text("Set a reminder").font(.caption)
                                    .foregroundStyle(CarTheme.muted)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(CarTheme.muted)
                    }
                    .padding(17)
                    .background(CarTheme.surface, in: RoundedRectangle(cornerRadius: 18))
                }
            }
            .padding(18)
        }
        .scrollIndicators(.hidden)
        .simultaneousGesture(
            DragGesture(minimumDistance: 70).onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) * 1.4 else { return }
                store.nextCar(direction: value.translation.width < 0 ? 1 : -1)
            }
        )
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomNavigation }
        .sheet(isPresented: $editingCar) { VehicleEditorView(store: store) }
        .navigationBarHidden(true)
        .buttonStyle(.plain)
        .carPage()
    }

    private var carPhoto: some View {
        ZStack(alignment: .topTrailing) {
            GeometryReader { bounds in
                ZStack {
                    LinearGradient(colors: [
                        Color(red: 0.16, green: 0.25, blue: 0.39),
                        CarTheme.surface
                    ], startPoint: .topLeading, endPoint: .bottomTrailing)
                    if let photo = store.carPhoto {
                        Image(uiImage: photo)
                            .resizable().scaledToFill()
                            .frame(width: bounds.size.width, height: bounds.size.height)
                            .clipped()
                    } else {
                        Image(systemName: "car.side.fill")
                            .resizable().scaledToFit()
                            .foregroundStyle(.white.opacity(0.28))
                            .frame(width: bounds.size.width * 0.68)
                    }
                }
                .frame(width: bounds.size.width, height: bounds.size.height)
            }
            .frame(height: 225)
            .clipShape(RoundedRectangle(cornerRadius: 23))

            VehiclePhotoButton(store: store)
                .labelStyle(.iconOnly)
                .padding(11)
                .background(.black.opacity(0.6), in: Circle())
                .padding(12)
        }
        .accessibilityElement(children: .contain)
    }

    private var bottomNavigation: some View {
        HStack(spacing: 0) {
            navLink("Problems", icon: "engine.combustion.fill") {
                ProblemsView(store: store)
            }
            navLink("Tires", icon: "circle.dotted.circle.fill") {
                TiresView(store: store)
            }
            Button { editingCar = true } label: {
                navLabel("My Car", icon: "car.fill", selected: true)
            }
            .frame(maxWidth: .infinity)
            navLink("Service", icon: "wrench.and.screwdriver.fill") {
                ServiceView(store: store)
            }
            navLink("Settings", icon: "gearshape.fill") {
                SettingsView(store: store)
            }
        }
        .padding(.top, 11)
        .padding(.bottom, 5)
        .background {
            CarTheme.surface
                .ignoresSafeArea(edges: .bottom)
                .overlay(alignment: .top) { Divider().overlay(CarTheme.raised) }
        }
    }

    private func navLink<Content: View>(_ label: LocalizedStringKey, icon: String,
                                        @ViewBuilder destination: () -> Content) -> some View {
        NavigationLink(destination: destination) {
            navLabel(label, icon: icon, selected: false)
        }
        .frame(maxWidth: .infinity)
    }

    private func navLabel(_ label: LocalizedStringKey, icon: String, selected: Bool) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 20, weight: .semibold))
            Text(label).font(.system(size: 10, weight: .medium)).lineLimit(1)
        }
        .foregroundStyle(selected ? CarTheme.accent : CarTheme.muted)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 48)
        .contentShape(Rectangle())
    }
}

/// Opens the system photo picker without requesting full photo-library access.
/// Used directly on the odometer card and in Settings.
struct VehiclePhotoButton: View {
    @ObservedObject var store: GarageStore
    @State private var selection: PhotosPickerItem?
    @State private var photoError = false

    var body: some View {
        PhotosPicker(selection: $selection, matching: .images) {
            Label("Change car photo", systemImage: "camera.fill")
        }
        .accessibilityLabel("Change car photo")
        .onChange(of: selection) { _, selected in
            guard let selected else { return }
            Task {
                let data = try? await selected.loadTransferable(type: Data.self)
                guard let data, store.updateCarPhoto(from: data) else {
                    photoError = true
                    return
                }
                selection = nil
            }
        }
        .alert("Photo could not be saved", isPresented: $photoError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Select a supported image from your photo library.")
        }
    }
}
