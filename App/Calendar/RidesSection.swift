import ClubKit
import SwiftUI

/// Car pools of an appointment: drivers offer seats, members take one for themselves or their wards.
/// `open` until the appointment starts; afterwards they are only shown.
struct RidesSection: View {
    let model: RidesModel
    let open: Bool

    @State private var seats = 3
    @State private var note = ""
    @State private var cancelling: Ride?
    @Environment(\.theme) private var theme

    /// club-client `settings.calendar.rideNoteMaxLength`.
    private let noteMaxLength = 200

    var body: some View {
        Section {
            if let rides = model.rides {
                if rides.isEmpty {
                    Text(open ? "Noch keine Fahrgemeinschaft. Wer fährt, kann hier Plätze anbieten." : "Keine Fahrgemeinschaft.")
                        .foregroundStyle(theme.textMuted)
                }
                ForEach(rides) { row($0) }
            } else {
                ProgressView()
            }
        } header: {
            Text("Fahrgemeinschaft")
        } footer: {
            if let error = model.error { Text(error).foregroundStyle(.red) }
        }
        .task { if model.rides == nil { await model.load() } }
        .confirmationDialog("Fahrt absagen?", isPresented: Binding(get: { cancelling != nil }, set: { if !$0 { cancelling = nil } }), titleVisibility: .visible) {
            Button("Fahrt absagen", role: .destructive) {
                if let ride = cancelling { Task { await model.cancel(ride) } }
            }
        } message: {
            Text("Die Mitfahrenden werden benachrichtigt.")
        }
        if open, model.rides != nil, !model.driving {
            offerForm
        }
    }

    private func row(_ ride: Ride) -> some View {
        let me = model.me.member.id
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(ride.driverName).font(theme.font(.body, weight: .semibold))
                Spacer()
                Group {
                    if ride.free > 0 { Text("\(ride.free) von \(ride.seats) frei") } else { Text("voll") }
                }
                .font(theme.font(.subheadline)).foregroundStyle(theme.textMuted)
            }
            if let note = ride.note, !note.isEmpty {
                Text(note).font(theme.font(.subheadline)).foregroundStyle(theme.textMuted)
            }
            ForEach(ride.passengers) { passenger in
                HStack {
                    Label(passenger.name, systemImage: "person")
                    Spacer()
                    if open && Rides.mayRemove(ride, passenger.memberId, me: model.me) {
                        Button { Task { await model.leave(ride, passenger.memberId) } } label: {
                            Image(systemName: "xmark.circle")
                        }
                        .buttonStyle(.borderless)
                        .disabled(model.busy)
                        .accessibilityLabel(Text("\(passenger.name) aussteigen lassen"))
                    }
                }
            }
            if open && ride.free > 0 {
                ForEach(Rides.riders(ride, me: model.me), id: \.self) { id in
                    Button { Task { await model.join(ride, id) } } label: {
                        if id == me { Text("Mitfahren") } else { Text("\(model.name(id)) mitnehmen") }
                    }
                    .buttonStyle(.borderless)
                    .disabled(model.busy)
                }
            }
            if open && ride.driverId == me {
                Button("Fahrt absagen", role: .destructive) { cancelling = ride }
                    .buttonStyle(.borderless)
                    .disabled(model.busy)
            }
        }
        .padding(.vertical, 2)
    }

    private var offerForm: some View {
        Section {
            Picker("Ich fahre und habe", selection: $seats) {
                ForEach(1...max(model.maxSeats, 1), id: \.self) { n in
                    if n == 1 { Text("1 Platz").tag(n) } else { Text("\(n) Plätze").tag(n) }
                }
            }
            TextField("Hinweis (optional)", text: $note, prompt: Text("z. B. Abfahrt 17:30 bei der Halle"))
                .onChange(of: note) { if note.count > noteMaxLength { note = String(note.prefix(noteMaxLength)) } }
            Button("Fahrt anbieten") {
                Task { if await model.offer(seats: seats, note: note) { note = "" } }
            }
            .disabled(model.busy)
        } header: {
            Text("Fahrt anbieten")
        }
    }
}
