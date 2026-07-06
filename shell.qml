//@ pragma Env QS_CRASHREPORT_URL=https://github.com/caelestia-dots/shell/issues/new?template=crash.yml
//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1
//@ pragma DefaultEnv QS_DROP_EXPENSIVE_FONTS=1
//@ pragma DefaultEnv QSG_RENDER_LOOP=threaded
//@ pragma DefaultEnv QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

import "modules"
import "modules/drawers"
import "modules/background"
import "modules/areapicker"
import "modules/lock"
import Quickshell

ShellRoot {
    settings.watchFiles: true   // Only during development? What's the performance loss?

    GSFLoader {}    // ./modules/ - FontLoader for Google Sans Flex font in: ./assets/google-sans-flex/
    // ^^ What is it used for and is it needed?

    Background {}   // ./modules/background/ - Background wallpaper, desktop clock, visualizer, etc.
    Drawers {}      // ./modules/drawers/ - Supposidly the core, but I don't understand how
    AreaPicker {}   // ./modules/areapicker/ - Lazy region picker for screenshots
    Lock {          // ./modules/lock/ - Session lock. I'm assuming it's just the lock screen UI, but idk.
        id: lock
    }

    ConfigToasts {} // ./modules/ - Toasts on config errors, whatever that means.
    Shortcuts {}    // ./modules/ - Keybinds I think.
    BatteryMonitor {} // ./modules/ -
    IdleMonitors {  // ./modules/ -
        lock: lock
    }
}
