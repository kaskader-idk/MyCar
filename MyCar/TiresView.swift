import SwiftUI

struct TiresView: View {
    @ObservedObject var store: GarageStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Tread depth")
                    .font(.largeTitle.bold())
                Text("Tap a tire to view or change its depth.")
                    .foregroundStyle(CarTheme.muted)
                Panel {
                    VStack(spacing: 0) {
                        Text("FRONT")
                            .font(.caption2.bold())
                            .tracking(2)
                            .foregroundStyle(CarTheme.muted)
                        tireMap
                        Text("REAR")
                            .font(.caption2.bold())
                            .tracking(2)
                            .foregroundStyle(CarTheme.muted)
                    }
                }
                SectionLabel(title: "Measurements", symbol: "ruler")
                ForEach(TirePosition.allCases) { position in
                    NavigationLink {
                        TireDetailView(store: store, position: position)
                    } label: {
                        HStack {
                            Image(systemName: "circle.dotted.circle.fill")
                                .foregroundStyle(CarTheme.accent)
                            Text(LocalizedStringKey(position.localizationKey))
                            Spacer()
                            if let mm = store.snapshot.tire(at: position).treadDepthMM {
                                Text(mm, format: .number.precision(.fractionLength(1)))
                                    .fontWeight(.semibold)
                                Text("mm").foregroundStyle(CarTheme.muted)
                            } else {
                                Text("Not measured").foregroundStyle(CarTheme.muted)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(CarTheme.muted)
                        }
                        .padding(16)
                        .background(CarTheme.surface, in: RoundedRectangle(cornerRadius: 17))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("Tires")
        .navigationBarTitleDisplayMode(.inline)
        .carPage()
    }

    private var tireMap: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 40)
                .fill(LinearGradient(colors: [CarTheme.raised, CarTheme.background],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 155, height: 315)
                .overlay {
                    VStack(spacing: 7) {
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(CarTheme.accent.opacity(0.4), lineWidth: 2)
                            .frame(width: 108, height: 91)
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(.white.opacity(0.2), lineWidth: 2)
                            .frame(width: 122, height: 90)
                        Spacer()
                        RoundedRectangle(cornerRadius: 17)
                            .stroke(.white.opacity(0.12), lineWidth: 2)
                            .frame(width: 110, height: 75)
                    }
                    .padding(.vertical, 23)
                }
            VStack {
                tireAxle(left: .frontLeft, right: .frontRight)
                Spacer()
                tireAxle(left: .rearLeft, right: .rearRight)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 355)
        .padding(.vertical, 12)
    }

    private func tireAxle(left: TirePosition, right: TirePosition) -> some View {
        HStack {
            tireButton(left)
            Spacer(minLength: 125)
            tireButton(right)
        }
    }

    private func tireButton(_ position: TirePosition) -> some View {
        NavigationLink {
            TireDetailView(store: store, position: position)
        } label: {
            VStack(spacing: 7) {
                RoundedRectangle(cornerRadius: 9)
                    .fill(CarTheme.raised)
                    .frame(width: 40, height: 84)
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(CarTheme.accent, lineWidth: 2)
                            .padding(5)
                    }
                if let depth = store.snapshot.tire(at: position).treadDepthMM {
                    Text(depth, format: .number.precision(.fractionLength(1)))
                        .font(.caption.bold())
                    + Text(" mm").font(.caption2)
                } else {
                    Text("—").font(.caption.bold())
                }
            }
            .frame(minWidth: 62, minHeight: 110)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(LocalizedStringKey(position.localizationKey)))
    }
}

struct TireDetailView: View {
    @ObservedObject var store: GarageStore
    let position: TirePosition
    @Environment(\.dismiss) private var dismiss
    @State private var depth: String
    @State private var notes: String

    init(store: GarageStore, position: TirePosition) {
        self.store = store
        self.position = position
        let tire = store.snapshot.tire(at: position)
        _depth = State(initialValue: tire.treadDepthMM.map { String(format: "%.1f", $0) } ?? "")
        _notes = State(initialValue: tire.notes)
    }

    private var parsedDepth: Double? {
        Double(depth.replacingOccurrences(of: ",", with: "."))
    }

    private var valid: Bool {
        depth.isEmpty || (parsedDepth.map { $0.isFinite && (0...15).contains($0) } ?? false)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Text(LocalizedStringKey(position.localizationKey))
                    .font(.largeTitle.bold())
                TireArtwork()
                    .frame(height: 255)
                    .accessibilityHidden(true)
                Panel {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Tread depth (mm)").font(.headline)
                        TextField("e.g. 5.5", text: $depth)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 35, weight: .semibold, design: .rounded))
                            .padding()
                            .background(CarTheme.raised, in: RoundedRectangle(cornerRadius: 15))
                        if !valid {
                            Text("Enter a value between 0 and 15 mm.")
                                .font(.caption)
                                .foregroundStyle(CarTheme.danger)
                        }
                        Text("Notes").font(.headline)
                        TextField("Optional tire notes", text: $notes, axis: .vertical)
                            .lineLimit(2...5)
                            .padding(12)
                            .background(CarTheme.raised, in: RoundedRectangle(cornerRadius: 12))
                        if let measured = store.snapshot.tire(at: position).measuredAt {
                            HStack {
                                Text("Last measured")
                                Spacer()
                                Text(measured, format: .dateTime.day().month().year())
                            }
                            .font(.caption)
                            .foregroundStyle(CarTheme.muted)
                        }
                    }
                }
                Button("Save measurement") {
                    store.updateTire(position: position, treadDepthMM: parsedDepth, notes: notes)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .controlSize(.large)
                .disabled(!valid)
                Text("Leave the value empty to clear a measurement.")
                    .font(.caption)
                    .foregroundStyle(CarTheme.muted)
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("Tire details")
        .navigationBarTitleDisplayMode(.inline)
        .carPage()
    }
}

private struct TireArtwork: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(CarTheme.raised)
                .frame(width: 225, height: 225)
                .overlay {
                    Circle().stroke(CarTheme.accent.opacity(0.7), lineWidth: 14).padding(9)
                }
            ForEach(0..<20, id: \.self) { index in
                Capsule()
                    .fill(CarTheme.background)
                    .frame(width: 13, height: 26)
                    .offset(y: -92)
                    .rotationEffect(.degrees(Double(index) * 18))
            }
            Circle().stroke(.white.opacity(0.35), lineWidth: 4).frame(width: 115, height: 115)
            Circle().fill(CarTheme.background).frame(width: 91, height: 91)
            Image(systemName: "ruler")
                .font(.system(size: 35))
                .foregroundStyle(CarTheme.accent)
        }
    }
}
