import Foundation

enum CCLangTutorNotification {
    static let newPrompt = Notification.Name("sh.saqoo.cclangtutor.newPrompt")
}

extension Notification.Name {
    static let hookConfigurationChanged = Notification.Name("sh.saqoo.cclangtutor.hookConfigurationChanged")
}
