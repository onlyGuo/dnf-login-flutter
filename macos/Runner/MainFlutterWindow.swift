import Cocoa
import FlutterMacOS
import bitsdojo_window_macos

class MainFlutterWindow: BitsdojoWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    flutterViewController.backgroundColor = NSColor.clear
    flutterViewController.view.wantsLayer = true
    flutterViewController.view.layer?.backgroundColor = NSColor.clear.cgColor

    self.styleMask = [.borderless, .fullSizeContentView, .miniaturizable]
    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true
    self.isOpaque = false
    self.backgroundColor = NSColor.clear
    self.hasShadow = false
    self.level = .normal
    self.isMovable = true
    self.isMovableByWindowBackground = true
    self.collectionBehavior.insert(.fullScreenNone)
    self.contentView?.wantsLayer = true
    self.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
    if let contentView = self.contentView,
       let superview = contentView.superview {
      superview.wantsLayer = true
      superview.layer?.backgroundColor = NSColor.clear.cgColor
      superview.layer?.masksToBounds = false
      if let superSuperView = superview.superview {
        superSuperView.wantsLayer = true
        superSuperView.layer?.backgroundColor = NSColor.clear.cgColor
        superSuperView.layer?.masksToBounds = false
      }
    }
    self.standardWindowButton(.closeButton)?.isHidden = true
    self.standardWindowButton(.miniaturizeButton)?.isHidden = true
    self.standardWindowButton(.zoomButton)?.isHidden = true

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
