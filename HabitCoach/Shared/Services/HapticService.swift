#if os(watchOS)
import WatchKit

struct HapticService {
    static func play(_ pattern: HapticPattern) {
        let wkType: WKHapticType = switch pattern {
        case .notification: .notification
        case .click: .click
        case .success: .success
        case .directionUp: .directionUp
        case .retry: .retry
        }
        WKInterfaceDevice.current().play(wkType)
    }
}
#endif
