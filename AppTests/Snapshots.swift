import ClubKit
import SwiftUI
import Testing
import UIKit
@testable import ClubApp

/// Renders screens in light and dark mode as PNGs into `SNAPSHOT_DIR` (CI uploads them as an artifact).
/// Nothing is compared: they are there to look at the style without a Mac.
@MainActor
@Suite(.enabled(if: ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] != nil))
struct Snapshots {
    @Test func login() throws {
        try snap("login", LoginView(club: .sample, logoURL: nil, signIn: { _, _ in }, resetPassword: { _ in }))
    }

    @Test func forgotPassword() throws {
        try snap("forgot-password", ForgotPasswordView(email: "anna@example.at") { _ in })
    }

    @Test func locked() throws {
        try snap("locked", LockedView(club: .sample, logoURL: nil, unlock: {}, signOut: {}))
    }

    @Test func onboarding() throws {
        try snap("onboarding", OnboardingView(me: .sample, save: { _ in }, signOut: {}))
    }

    @Test func start() throws {
        try snap("start", StartView(club: .sample, logoURL: nil, me: .sample))
    }

    @Test func more() throws {
        try snap("more", MoreView(api: .offline, me: .sample, calendar: .club(.sample), signOut: {}))
    }

    @Test func calendarMonth() throws {
        try snap("calendar-month", CalendarView(model: .sample))
    }

    @Test func appointment() throws {
        let model = AppointmentModel(api: .offline, me: .sample, id: "a1", types: CalendarModel.sampleTypes)
        model.appointment = decode("""
            {"id":"a1","teamId":"t1","type":"MATCH","title":"Heimspiel gegen Hietzing","description":"Treffpunkt 30 Minuten vorher.",
             "location":"Sporthalle Hernals","startsAt":"\(at(days: 2, hour: 18))","endsAt":"\(at(days: 2, hour: 20))","cancelled":false,"rides":true}
            """)
        model.rides.rides = decode("""
            [{"id":"r1","driverId":"m2","driverName":"Lena Huber","seats":3,"note":"Abfahrt 17:15 beim Bahnhof",
              "passengers":[{"memberId":"m3","name":"Mara Klein"}]}]
            """)
        model.attendance = decode("""
            {"yes":2,"no":1,"maybe":0,"open":1,"entries":[
             {"memberId":"m1","name":"Anna Berger","status":"YES","absent":false,"unconfirmed":true},
             {"memberId":"m2","name":"Lena Huber","status":"YES","absent":false,"unconfirmed":false},
             {"memberId":"m3","name":"Mara Klein","status":"NO","reason":"Krank","absent":false,"unconfirmed":false},
             {"memberId":"m4","name":"Sophie Wolf","status":null,"absent":false,"unconfirmed":false}]}
            """)
        try snap("appointment", NavigationStack { AppointmentView(model: model) {} })
    }

    @Test func absences() throws {
        let model = AbsencesModel(api: .offline, me: .sample, calendar: .club(.sample))
        model.absences = decode("""
            [{"id":"x1","memberId":"m1","from":"\(day(3))","to":"\(day(9))","reason":"Urlaub"},
             {"id":"x2","memberId":"m1","from":"\(day(20))","to":"\(day(20))","reason":null}]
            """)
        try snap("absences", NavigationStack { AbsencesView(model: model) })
    }

    @Test func inbox() throws {
        let model = InboxModel(api: .offline)
        model.inbox = decode("""
            {"unread":1,"items":[
             {"id":"n1","kind":"APPOINTMENT_CHANGED","title":"Geänderter Termin: Heimspiel gegen Hietzing","body":"Neue Zeit: Sa 18:30",
              "link":"/appointments/a1","createdAt":"\(at(days: 0, hour: 9))","readAt":null},
             {"id":"n2","kind":"TASK_ASSIGNED","title":"Neue Aufgabe: Bälle aufpumpen","body":"","link":"/tasks/t1",
              "createdAt":"\(at(days: -1, hour: 17))","readAt":"\(at(days: -1, hour: 18))"}]}
            """)
        try snap("inbox", InboxView(model: model, me: .sample, calendar: .club(.sample)))
    }

    @Test func notificationPreferences() throws {
        let model = NotificationPreferencesModel(api: .offline)
        model.items = decode("""
            [{"kind":"TASK_ASSIGNED","push":true,"email":false},{"kind":"RIDE","push":true,"email":true},
             {"kind":"MEETING","push":true,"email":true}]
            """)
        model.important = ["MEETING"]
        try snap("notification-preferences", NavigationStack { NotificationPreferencesView(model: model) })
    }

    @Test func loadFailed() throws {
        try snap("load-failed", LoadFailedView {})
    }

    private func snap(_ name: String, _ view: some View) throws {
        let dir = URL(fileURLWithPath: ProcessInfo.processInfo.environment["SNAPSHOT_DIR"]!)
        let scene = try #require(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        for (style, suffix) in [(UIUserInterfaceStyle.light, "light"), (.dark, "dark")] {
            let window = UIWindow(windowScene: scene)
            window.frame = scene.screen.bounds
            window.overrideUserInterfaceStyle = style
            window.rootViewController = UIHostingController(rootView: view.clubStyle(.sample))
            window.isHidden = false
            window.layoutIfNeeded()
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                _ = window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            try #require(image.pngData()).write(to: dir.appending(path: "\(name)-\(suffix).png"))
            window.isHidden = true
        }
    }
}

/// The SDG brand guide as the club enters it in Erscheinungsbild (test data; the app reads the brand from the server).
extension Club {
    static let sample: Club = try! JSONDecoder().decode(Club.self, from: Data("""
        {"name":"SDG Vienna","timeZone":"Europe/Vienna","locale":"de-AT","assets":{"logo":null},
         "brand":{"primary":"#57263C","primaryHover":"#431C2E","accent":"#A8862F","text":"#1E1A1D","textMuted":"#6B5F66",
                  "tint":"#F5F0F2","line":"#E4DDE1","headingFont":"ANTON","textFont":"INTER","headingCaps":true,
                  "radiusSmall":4,"radiusLarge":8}}
        """.utf8))
}

extension Me {
    static let sample: Me = try! JSONDecoder().decode(Me.self, from: Data("""
        {"member":{"id":"m1","firstName":"Anna"},"missing":["birthDate"],"teams":[{"id":"t1","name":"Damen 1"}],
         "wardIds":[],"wardNames":{}}
        """.utf8))
}

extension ApiClient {
    /// Never reached: the snapshots set their data before the views load.
    static let offline = ApiClient(baseURL: URL(string: "http://localhost:9")!)
}

/// Days from today at a club-local hour, as the server sends instants.
private func at(days: Int, hour: Int) -> String {
    let cal = Calendar.club(.sample)
    let day = cal.date(byAdding: .day, value: days, to: cal.startOfDay(for: Date()))!
    return cal.date(bySettingHour: hour, minute: 0, second: 0, of: day)!.formatted(.iso8601)
}

/// A club day `days` from today as `yyyy-MM-dd`.
private func day(_ days: Int) -> String {
    let cal = Calendar.club(.sample)
    return cal.dayText(cal.date(byAdding: .day, value: days, to: Date())!)
}

private func decode<T: Decodable>(_ json: String) -> T {
    try! ApiClient.decoder().decode(T.self, from: Data(json.utf8))
}

extension CalendarModel {
    static let sampleTypes: [String: AppointmentType] = Dictionary(uniqueKeysWithValues: [
        ("TRAINING", "Training", "blue"), ("MATCH", "Spiel", "red"),
    ].map { key, label, hue -> (String, AppointmentType) in
        let type: AppointmentType = decode("""
            {"key":"\(key)","label":"\(label)","hue":"\(hue)","answerDeadlineHours":0,"allowMaybe":true,"reasonOnNo":true,"expectAnswers":"TEAM"}
            """)
        return (key, type)
    })

    @MainActor static var sample: CalendarModel {
        let model = CalendarModel(api: .offline, me: .sample, calendar: .club(.sample))
        model.types = sampleTypes
        model.items = decode("""
            [{"kind":"appointment","id":"a0","title":"Training Damen 1","start":"\(at(days: 0, hour: 19))","end":"\(at(days: 0, hour: 21))","allDay":false,"category":"APPOINTMENT","detail":"TRAINING","inactive":false},
             {"kind":"task","id":"t1","title":"Bälle aufpumpen","start":"\(at(days: 0, hour: 17))","end":null,"allDay":false,"category":"TASK","inactive":false},
             {"kind":"appointment","id":"a1","title":"Heimspiel gegen Hietzing","start":"\(at(days: 2, hour: 18))","end":"\(at(days: 2, hour: 20))","allDay":false,"category":"APPOINTMENT","detail":"MATCH","inactive":false},
             {"kind":"meeting","id":"mt","title":"Vorstandssitzung","start":"\(at(days: 3, hour: 19))","end":"\(at(days: 3, hour: 21))","allDay":false,"category":"MEETING","inactive":false},
             {"kind":"holiday","id":"h","title":"Feiertag","start":"\(at(days: 5, hour: 0))","end":"\(at(days: 6, hour: 0))","allDay":true,"category":"HOLIDAY","inactive":false}]
            """)
        model.marks = ["a0": .yes]
        model.openAnswers = decode("""
            [{"appointmentId":"a1","title":"Heimspiel gegen Hietzing","startsAt":"\(at(days: 2, hour: 18))","memberId":"m1","name":"Anna Berger"}]
            """)
        return model
    }
}
