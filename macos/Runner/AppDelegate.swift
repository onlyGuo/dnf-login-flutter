import Cocoa
import FlutterMacOS

@NSApplicationMain
class AppDelegate: FlutterAppDelegate {
  private let windowChannelName = "dnf/window_control"

  override func applicationDidFinishLaunching(_ notification: Notification) {
    if let controller = mainFlutterWindow?.contentViewController as? FlutterViewController {
      let windowChannel = FlutterMethodChannel(
        name: windowChannelName,
        binaryMessenger: controller.engine.binaryMessenger)

      windowChannel.setMethodCallHandler { [weak self] call, result in
        guard let window = self?.mainFlutterWindow else {
          result(FlutterError(code: "no_window", message: "Window unavailable", details: nil))
          return
        }

        switch call.method {
        case "minimize":
          window.miniaturize(nil)
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    super.applicationDidFinishLaunching(notification)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }
}
