import SwiftUI
import WatchKit

class NotificationController: WKUserNotificationHostingController<NotificationView> {
    override var body: NotificationView {
        NotificationView()
    }
}

struct NotificationView: View {
    var body: some View {
        Text("New Notification")
    }
}
