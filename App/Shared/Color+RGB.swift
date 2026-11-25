import ClubKit
import SwiftUI
import UIKit

extension Color {
    init(_ rgb: RGB) {
        self.init(UIColor(rgb))
    }
}

extension UIColor {
    convenience init(_ rgb: RGB) {
        self.init(red: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1)
    }
}
