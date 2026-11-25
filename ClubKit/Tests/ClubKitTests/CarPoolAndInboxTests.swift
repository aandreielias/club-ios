import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import ClubKit

private let me = try! JSONDecoder().decode(Me.self, from: Data("""
    {"member":{"id":"m1","firstName":"Anna"},"missing":[],"teams":[],"wardIds":["k2","k1"],"wardNames":{"k1":"Ben","k2":"Clara"}}
    """.utf8))

private func ride(driver: String, seats: Int = 3, passengers: [String] = []) -> Ride {
    let list = passengers.map { #"{"memberId":"\#($0)","name":"\#($0)"}"# }.joined(separator: ",")
    return try! JSONDecoder().decode(Ride.self, from: Data("""
        {"id":"r1","driverId":"\(driver)","driverName":"D","seats":\(seats),"note":null,"passengers":[\(list)]}
        """.utf8))
}

@Test func ridersAreSelfAndWardsNotYetAboard() {
    #expect(Rides.riders(ride(driver: "x", passengers: ["k1"]), me: me) == ["m1", "k2"])
    #expect(Rides.riders(ride(driver: "m1"), me: me) == ["k1", "k2"])  // the driver takes no seat in their own car
    #expect(ride(driver: "x", seats: 3, passengers: ["k1", "y"]).free == 1)
    #expect(Rides.driving([ride(driver: "m1")], me: me))
    #expect(!Rides.driving([ride(driver: "x")], me: me))
}

@Test func passengersLeaveBySelfGuardianOrDriver() {
    let other = ride(driver: "x", passengers: ["y", "k1"])
    #expect(Rides.mayRemove(other, "k1", me: me))
    #expect(!Rides.mayRemove(other, "y", me: me))
    #expect(Rides.mayRemove(ride(driver: "m1", passengers: ["y"]), "y", me: me))
}

@Test func plainDatesAreClubDays() {
    let calendar = Calendar.club(try! JSONDecoder().decode(Club.self, from: Data(sdgClub.utf8)))
    let day = try! #require(calendar.day("2026-03-29"))  // the day summer time starts in Vienna
    #expect(calendar.dayText(day) == "2026-03-29")
    #expect(calendar.dayText(calendar.date(byAdding: .day, value: 1, to: day)!) == "2026-03-30")
    #expect(calendar.day("29.03.2026") == nil)
}

@Test func notificationLinksOpenKnownRecords() throws {
    let inbox = try ApiClient.decoder().decode(Inbox.self, from: Data("""
        {"unread":1,"items":[
         {"id":"n1","kind":"APPOINTMENT_CHANGED","title":"t","body":"b","link":"/appointments/a1","createdAt":"2026-11-25T10:00:00Z","readAt":null},
         {"id":"n2","kind":"MAIL","title":"t","body":"b","link":"/mail/x/y","createdAt":"2026-11-25T10:00:00.5Z","readAt":"2026-11-25T11:00:00Z"},
         {"id":"n3","kind":"FEE","title":"t","body":"b","link":null,"createdAt":"2026-11-25T10:00:00Z","readAt":null}]}
        """.utf8))
    #expect(inbox.items.map(\.target) == [.appointment("a1"), nil, nil])
}

@Test func createsSendTheIdempotencyKey() async throws {
    let seen = SeenRequest()
    let api = ApiClient(baseURL: URL(string: "https://api.example.club")!, transport: { request in
        seen.request = request
        let body = #"{"id":"x","memberId":"m1","from":"2026-12-01","to":"2026-12-02","reason":null}"#
        return (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!)
    })
    _ = try await api.addAbsence(AbsenceBody(memberId: nil, from: "2026-12-01", to: "2026-12-02", reason: nil), key: "k-123456")
    let request = try #require(seen.request)
    #expect(request.httpMethod == "POST")
    #expect(request.value(forHTTPHeaderField: "Idempotency-Key") == "k-123456")
    let sent = try JSONSerialization.jsonObject(with: #require(request.httpBody)) as? [String: String]
    #expect(sent == ["from": "2026-12-01", "to": "2026-12-02"])  // no memberId = oneself
}

private final class SeenRequest: @unchecked Sendable {
    var request: URLRequest?
}

private let contract = URL(fileURLWithPath: #filePath).appending(path: "../../../Contract").standardized

@Test func everyServerErrorCodeHasAText() throws {
    let texts = try ErrorTexts(json: Data(contentsOf: contract.appending(path: "error-texts.json")))
    let codes = try JSONDecoder().decode([String].self, from: Data(contentsOf: contract.appending(path: "error-codes.json")))
    #expect(codes.filter { !texts.knows($0) } == [])
}

@Test func errorTextsFollowTheWeb() throws {
    let texts = try ErrorTexts(json: Data("""
        {"codes":{"absence.overlaps":"Schon eingetragen.","document.placeholder-unknown":"Unbekannt:","network":"Offline."},
         "status":{"404":"Nicht gefunden.","500":"Serverfehler."},"unknown":"Unbekannter Fehler."}
        """.utf8))
    func problem(_ status: Int, _ json: String) -> ProblemError { ProblemError(status: status, body: Data(json.utf8)) }
    #expect(texts.text(problem(409, #"{"code":"absence.overlaps"}"#)) == "Schon eingetragen.")
    #expect(texts.text(problem(400, #"{"code":"document.placeholder-unknown","details":["Foo","Bar"]}"#)) == "Unbekannt: Foo, Bar")
    #expect(texts.text(problem(404, #"{"code":"something.new"}"#)) == "Nicht gefunden.")
    #expect(texts.text(problem(500, #"{"code":"x.y","correlationId":"c9"}"#)) == "Serverfehler. Ref: c9")
    #expect(texts.text(problem(418, #"{"code":"x.y"}"#)) == "Unbekannter Fehler. (x.y)")
    #expect(texts.text(URLError(.notConnectedToInternet)) == "Offline.")
}
