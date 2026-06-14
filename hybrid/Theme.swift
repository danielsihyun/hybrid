import SwiftUI

// MARK: - Colors
extension Color {
    static let appBg       = Color(red: 10/255, green: 10/255, blue: 15/255)
    static let appCard     = Color(red: 22/255, green: 22/255, blue: 29/255)
    static let appMuted    = Color(red: 30/255, green: 30/255, blue: 40/255)
    static let appBorder   = Color(red: 42/255, green: 42/255, blue: 56/255)
    static let appSubtext  = Color(red: 138/255, green: 138/255, blue: 158/255)
    static let eCyan       = Color(red: 0,       green: 217/255, blue: 1)
    static let eGreen      = Color(red: 0,       green: 1,       blue: 136/255)
    static let ePurple     = Color(red: 184/255, green: 77/255,  blue: 1)
    static let ePink       = Color(red: 1,       green: 77/255,  blue: 158/255)
}

// MARK: - Gradients
extension LinearGradient {
    static let cyan     = LinearGradient(colors: [Color(red: 0,      green: 217/255, blue: 1),       Color(red: 0,      green: 153/255, blue: 1)],       startPoint: .topLeading, endPoint: .bottomTrailing)
    static let green    = LinearGradient(colors: [Color(red: 0,      green: 1,       blue: 136/255), Color(red: 0,      green: 204/255, blue: 106/255)],  startPoint: .topLeading, endPoint: .bottomTrailing)
    static let purple   = LinearGradient(colors: [Color(red: 184/255, green: 77/255, blue: 1),       Color(red: 136/255, green: 51/255, blue: 221/255)],  startPoint: .topLeading, endPoint: .bottomTrailing)
    static let pink     = LinearGradient(colors: [Color(red: 1,      green: 77/255,  blue: 158/255), Color(red: 221/255, green: 34/255, blue: 119/255)],  startPoint: .topLeading, endPoint: .bottomTrailing)
    static let darkCard = LinearGradient(colors: [Color(red: 30/255, green: 30/255,  blue: 40/255),  Color(red: 22/255,  green: 22/255, blue: 29/255)],   startPoint: .topLeading, endPoint: .bottomTrailing)
}
