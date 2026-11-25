import Foundation
import Testing
@testable import ClubKit

/// Every model the app decodes, against its server schema in `Contract/openapi.json` (copied by `scripts/api-sync.sh`).
/// A field the model reads that the server renamed, removed or retyped fails here. Nullability is not checked:
/// the snapshot marks every field required, so models declare `Optional` where the server may send null.
/// New model → add a line.
@Test func modelsMatchServer() throws {
    try check(Club.self, "at.clubserver.platform.club.ClubSettings.Club")
    try check(Me.self, "at.clubserver.gateway.rest.MembersController.Me")
    try checkBody(ProfileBody(birthDate: "2010-05-01"), "at.clubserver.gateway.rest.MembersController.ProfileBody")
    try check(CalendarItem.self, "at.clubserver.platform.CalendarItems.CalendarItem")
    try check(Appointment.self, "at.clubserver.calendar.api.CalendarApi.AppointmentDto")
    try check(AppointmentType.self, "at.clubserver.calendar.api.CalendarApi.AppointmentTypeDto")
    try check(Attendance.self, "at.clubserver.attendance.api.AttendanceApi.Attendance")
    try check(OpenAnswer.self, "at.clubserver.attendance.api.AttendanceApi.OpenAnswer")
    try check(MyAnswer.self, "at.clubserver.attendance.api.AttendanceApi.MyAnswer")
    try checkBody(AnswerBody(memberId: "m1", status: .no, reason: "krank"), "at.clubserver.gateway.rest.CalendarController.ResponseBody")
}

/// Request bodies: every key the app sends is a property of the server's schema.
private func checkBody(_ body: some Encodable, _ schema: String) throws {
    let schemas = (try loadSpec()["components"] as! [String: Any])["schemas"] as! [String: Any]
    let properties = try #require((schemas[schema] as? [String: Any])?["properties"] as? [String: Any], "unknown schema \(schema)")
    let sent = try JSONSerialization.jsonObject(with: JSONEncoder().encode(body)) as! [String: Any]
    #expect(Set(sent.keys).isSubset(of: properties.keys), "\(schema) lacks \(Set(sent.keys).subtracting(properties.keys))")
}

private func check<T: Decodable>(_: T.Type, _ schema: String) throws {
    let sample = try Sample(spec: loadSpec()).json(ref: "#/components/schemas/\(schema)")
    _ = try ApiClient.decoder().decode(T.self, from: JSONSerialization.data(withJSONObject: sample))
}

private func loadSpec() throws -> [String: Any] {
    let url = URL(fileURLWithPath: #filePath).appending(path: "../../../Contract/openapi.json").standardized
    return try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
}

/// Builds a JSON value with every property set, from an OpenAPI 3.1 schema.
private struct Sample {
    let spec: [String: Any]

    func json(ref: String, seen: Set<String> = []) throws -> Any {
        guard !seen.contains(ref) else { return NSNull() }
        let name = ref.replacingOccurrences(of: "#/components/schemas/", with: "")
        let schemas = (spec["components"] as! [String: Any])["schemas"] as! [String: Any]
        guard let schema = schemas[name] as? [String: Any] else { throw ContractError.unknownSchema(name) }
        return try json(schema, seen: seen.union([ref]))
    }

    private func json(_ schema: [String: Any], seen: Set<String>) throws -> Any {
        if let ref = schema["$ref"] as? String { return try json(ref: ref, seen: seen) }
        if let first = ((schema["oneOf"] ?? schema["anyOf"] ?? schema["allOf"]) as? [[String: Any]])?.first {
            return try json(first, seen: seen)
        }
        if let values = schema["enum"] as? [Any], let first = values.first { return first }
        let type = (schema["type"] as? String) ?? (schema["type"] as? [String])?.first { $0 != "null" } ?? "object"
        switch type {
        case "string":
            switch schema["format"] as? String {
            case "date-time": return "2026-01-01T12:00:00Z"
            case "date": return "2026-01-01"
            default: return "#5E6AD2"  // valid for colour fields too; plain strings accept anything
            }
        case "integer", "number": return 1
        case "boolean": return true
        case "array": return [try json(schema["items"] as? [String: Any] ?? [:], seen: seen)]
        default:
            let properties = schema["properties"] as? [String: [String: Any]] ?? [:]
            return try properties.mapValues { try json($0, seen: seen) }
        }
    }
}

private enum ContractError: Error { case unknownSchema(String) }
