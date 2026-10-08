import Quickshell

ShellRoot {
    // Hot-reload on save while iterating
    settings.watchFiles: true

    Variants {
        model: Quickshell.screens

        Background {
            required property ShellScreen modelData
            screen: modelData
        }
    }

    Variants {
        model: Quickshell.screens

        Bar {
            required property ShellScreen modelData
            screen: modelData
        }
    }

    Variants {
        model: Quickshell.screens

        WorkspaceDock {
            required property ShellScreen modelData
            screen: modelData
        }
    }
}
