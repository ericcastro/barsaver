import AppKit
import BarsaverCore
import Foundation

@MainActor
private final class CLIAppDelegate: NSObject, NSApplicationDelegate {
    private let runtime: BarsaverRuntime
    private var signalSources: [DispatchSourceSignal] = []

    init(runtime: BarsaverRuntime) {
        self.runtime = runtime
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.prohibited)
        installSignalHandlers()
        runtime.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        signalSources.forEach { $0.cancel() }
        runtime.stop()
    }

    private func installSignalHandlers() {
        signal(SIGINT, SIG_IGN)
        signal(SIGTERM, SIG_IGN)

        for signalValue in [SIGINT, SIGTERM] {
            let source = DispatchSource.makeSignalSource(signal: signalValue, queue: .main)
            source.setEventHandler {
                NSApp.terminate(nil)
            }
            source.resume()
            signalSources.append(source)
        }
    }
}

do {
    let options = try CLIParser.parse(arguments: Array(CommandLine.arguments.dropFirst()))
    let configuration = try MarqueeConfiguration.load(from: options.configPath)
    let selection = try options.selectionOverride ?? MarqueeConfiguration.displaySelection(from: configuration)

    if options.shouldListDisplays {
        DisplayManager.printDisplays()
        guard options.selectionOverride != nil else {
            Foundation.exit(EXIT_SUCCESS)
        }
    }

    let app = NSApplication.shared
    let runtime = try BarsaverRuntime(configuration: configuration, selection: selection)
    let delegate = CLIAppDelegate(runtime: runtime)
    app.delegate = delegate
    withExtendedLifetime((delegate, runtime)) {
        app.run()
    }
} catch {
    fputs("\(error.localizedDescription)\n\n\(CLIParser.usage)\n", stderr)
    Foundation.exit(EXIT_FAILURE)
}
