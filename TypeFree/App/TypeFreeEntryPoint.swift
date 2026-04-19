import AppKit

protocol ApplicationRuntimeControlling: AnyObject {
    var delegate: NSApplicationDelegate? { get set }

    @discardableResult
    func setActivationPolicy(_ activationPolicy: NSApplication.ActivationPolicy) -> Bool
    func run()
}

extension NSApplication: ApplicationRuntimeControlling {}

@main
struct TypeFreeEntryPoint {
    static let activationPolicy: NSApplication.ActivationPolicy = .accessory

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        configure(application: app, delegate: delegate)
        app.run()
    }

    static func configure(
        application: any ApplicationRuntimeControlling,
        delegate: NSApplicationDelegate
    ) {
        _ = application.setActivationPolicy(activationPolicy)
        application.delegate = delegate
    }
}
