/// Labels and hints of the notification kinds, in the web's order (club-client `NOTIFICATION_KINDS`).
enum NotificationKinds {
    static let all: [(kind: String, label: String, hint: String)] = [
        ("TASK_ASSIGNED", String(localized: "Neue Aufgaben"), String(localized: "Wenn dir eine Aufgabe zugewiesen wird.")),
        ("TASK_ACTIVITY", String(localized: "Kommentare und erledigte Aufgaben"), String(localized: "Neue Kommentare zu deinen Aufgaben; wenn eine Aufgabe, die du angelegt hast, erledigt ist.")),
        ("TASK_DUE", String(localized: "Fällige Aufgaben"), String(localized: "Vor der Fälligkeit; wie lange vorher, legt der Verein fest.")),
        ("APPOINTMENT_CANCELLED", String(localized: "Abgesagte Termine"), String(localized: "Wenn ein Termin für dich ausfällt.")),
        ("APPOINTMENT_CHANGED", String(localized: "Geänderte Termine"), String(localized: "Neue Zeit, neuer Ort oder neue Kabine eines kommenden Termins.")),
        ("ATTENDANCE", String(localized: "Zu- und Absagen"), String(localized: "Erinnerung, wenn du noch nicht geantwortet hast; für Trainer:innen: Abwesenheit trotz Zusage.")),
        ("RIDE", String(localized: "Fahrgemeinschaften"), String(localized: "Wer in dein Auto steigt oder aussteigt, und wenn deine Mitfahrt ausfällt.")),
        ("ITEM_REMINDER", String(localized: "Gegenstände mitbringen"), String(localized: "Vor einem Termin, für den du etwas aus dem Inventar hast.")),
        ("CHANGE_DECIDED", String(localized: "Kontoänderungen"), String(localized: "Wenn der Vorstand über deine Änderungsanfrage entschieden hat.")),
        ("TEAM", String(localized: "Teams"), String(localized: "Für Vorstand und Admins: wenn Trainer:innen jemanden ins Team aufnehmen möchten.")),
        ("MAIL", String(localized: "Neue E-Mails"), String(localized: "Wenn in deinem Vereins-Postfach oder einem geteilten Postfach eine E-Mail ankommt.")),
        ("FEE", String(localized: "Mitgliedsbeiträge"), String(localized: "Erinnerung, wenn dein Beitrag oder der deiner Kinder überfällig ist.")),
        ("MEETING", String(localized: "Sitzungen"), String(localized: "Einladungen, Umlaufbeschlüsse und Erinnerungen an Fristen.")),
    ]
}
