import AppKit
import Foundation

do {
    let options = try CLIParser.parse(arguments: Array(CommandLine.arguments.dropFirst()))
    let app = NSApplication.shared
    let configuration = try MarqueeConfiguration.load(from: options.configPath)
    let blocks = try MarqueePluginRegistryValue().makeBlocks(from: configuration.blocks)
    let contentController = MarqueeContentController(blocks: blocks)
    let holdToClickModifier = InteractionConfiguration.modifierFlags(for: configuration.settings["hold_to_click_key"])

    if options.shouldListDisplays {
        DisplayManager.printDisplays()
        guard CommandLine.arguments.contains("--displays") else {
            Foundation.exit(EXIT_SUCCESS)
        }
    }

    let delegate = AppDelegate(
        selection: options.selection,
        contentController: contentController,
        holdToClickModifier: holdToClickModifier
    )
    app.delegate = delegate
    withExtendedLifetime((delegate, contentController)) {
        app.run()
    }
} catch {
    fputs("\(error.localizedDescription)\n\n\(CLIParser.usage)\n", stderr)
    Foundation.exit(EXIT_FAILURE)
}
