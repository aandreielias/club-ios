import LocalAuthentication

/// Face ID / Touch ID in front of a stored session. Devices without it enrolled open without a lock.
enum Biometrics {
    static var available: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    /// Falls back to the device passcode when Face ID fails.
    static func unlock() async -> Bool {
        (try? await LAContext().evaluatePolicy(.deviceOwnerAuthentication, localizedReason: String(localized: "Anmeldung entsperren"))) ?? false
    }
}
