# Quoil Architecture

Quoil is a Quickshell-based desktop shell for Hyprland (a fork of Caelestia). It is a single
Quickshell config (`shell.qml`) that creates every UI surface — bar, drawers, lock screen,
wallpaper, screenshot picker — plus a settings app, backed by a layer of QML service
singletons and a compiled C++ QML plugin.

> **Naming note:** the fork renamed the QML module URIs to `Quoil.*`, but a lot of internals
> still carry the Caelestia name: the C++ sources live in `plugin/src/Caelestia/`, the config
> file is read from `~/.config/caelestia/shell.json`, runtime state lives in
> `~/.local/state/caelestia/`, global shortcuts use appid `caelestia`, and several services
> still shell out to an external `caelestia` CLI (see [Caveats](#caveats--ambiguities)).

---

## Entry point and load order

`shell.qml` is the root. It sets a few env pragmas (threaded render loop, no reload popup),
enables `settings.watchFiles` (live QML reload on file change), and instantiates, in order:

| # | Component | File | Role |
|---|-----------|------|------|
| 1 | `GSFLoader` | `modules/GSFLoader.qml` | `FontLoader` for the Google Sans Flex variable font in `assets/google-sans-flex/` |
| 2 | `Background` | `modules/background/Background.qml` | Per-screen wallpaper/visualiser/desktop-clock window |
| 3 | `Drawers` | `modules/drawers/Drawers.qml` | **The core.** One full-screen layer-shell window per screen hosting the bar and every slide-out panel |
| 4 | `AreaPicker` | `modules/areapicker/AreaPicker.qml` | Screenshot region picker (lazy-loaded) |
| 5 | `Lock` | `modules/lock/Lock.qml` | `WlSessionLock` session lock + PAM auth |
| 6 | `ConfigToasts` | `modules/ConfigToasts.qml` | Toasts on config load/save errors |
| 7 | `Shortcuts` | `modules/Shortcuts.qml` | All global keybind handlers + IPC handlers |
| 8 | `BatteryMonitor` | `modules/BatteryMonitor.qml` | UPower-driven battery warning toasts |
| 9 | `IdleMonitors` | `modules/IdleMonitors.qml` | Idle timeouts → lock/DPMS/suspend actions (receives a reference to `Lock`) |

Everything else — the ~20 service singletons in `services/`, the C++ singletons, and the
`Nexus` settings window — is instantiated lazily: QML singletons on first reference,
Nexus on demand via `WindowFactory.create()`.

---

## The general pattern

Four mechanisms tie the whole config together:

1. **Per-screen `Variants`.** `Drawers`, `Background`, `Exclusions`, and `AreaPicker` each wrap
   their window in `Variants { model: Screens.screens }`, so every enabled monitor gets its own
   instance. `services/Screens.qml` filters `Quickshell.screens` through per-screen config.

2. **The `Visibilities` registry (drawer open/close state).** Each screen's drawer window owns a
   `DrawerVisibilities` object (`components/DrawerVisibilities.qml`) — a `PersistentProperties`
   with one bool per drawer (`bar, osd, session, launcher, dashboard, utilities, sidebar`).
   On creation it registers itself in the `services/Visibilities.qml` singleton keyed by
   Hyprland monitor. Anything that wants to open a drawer (keybind, IPC, hover interaction,
   another module) calls `Visibilities.getForActive()` and flips a bool; the drawer wrappers
   are pure declarative consumers of those bools. **This is the main cross-module signal bus.**

3. **`GlobalConfig` / `Config` / `Tokens` (C++, `Quoil.Config`).** `GlobalConfig` is a C++
   singleton that live-loads `~/.config/caelestia/shell.json` (hot reload, per-screen
   overrides, unknown-key warnings). `Config` and `Tokens` are *attached properties*: any Item
   can read `Config.bar.…` or `Tokens.rounding.…` and gets values resolved for the screen its
   window is on. Virtually every QML file imports `Quoil.Config` (220 imports).

4. **Wrapper/Content convention.** Every drawer module is split into a `Wrapper.qml`
   (size/reveal animation driven by its visibility bool, collapses to 0 when hidden) and a
   `Content.qml` (the actual UI), usually loaded through `AnimLoader`/`Loader` so hidden
   panels cost nothing.

---

## Module-by-module

### Drawer system — `modules/drawers/`

- **Purpose:** the container for all interactive shell UI. Renders the screen border, the
  left bar, and hosts every slide-out panel in a single full-screen window per monitor.
- **Files:**
  - `Drawers.qml` — `Variants` over screens; per screen creates `Exclusions` + `ContentWindow`.
  - `ContentWindow.qml` — the full-screen `StyledWindow` (layer-shell name `drawers`,
    exclusion ignored, layer Top — or Overlay above fullscreen windows). Handles fullscreen
    detection via Hyprland IPC (hides everything, closes drawers), keyboard-focus policy,
    a `HyprlandFocusGrab` that closes drawers on outside click, and the SDF "blob" border
    rendering (`BlobGroup`/`BlobRect`/`BlobInvertedRect` from the C++ `Quoil.Blobs` module)
    that lets panels morph out of the border.
  - `Panels.qml` — instantiates all drawer wrappers and positions them: OSD (right-center),
    Notifications (top-right), Session (right), Launcher (bottom-center), Dashboard
    (top-center), Bar popouts (left, next to bar), Utilities (bottom-right), Toasts,
    Sidebar (right).
  - `Interactions.qml` — a screen-covering `CustomMouseArea` implementing hover-reveal and
    drag-to-open gestures on the screen edges, and wheel-on-bar handling.
  - `Regions.qml` — computes the input-mask region (XOR of bar + open panels) so the
    full-screen window is click-through everywhere else.
  - `Exclusions.qml` — four 1-px `StyledWindow`s that reserve layout space (bar width on the
    left, border thickness elsewhere) via `exclusiveZone`, since the main window ignores
    exclusion.
- **Triggered:** always loaded; individual panels shown via `DrawerVisibilities` bools.
- **Data flow:** reads `Hypr` (fullscreen/special-workspace state), `Colours`, `Config.border`.
  Registers per-screen state into `Visibilities`.
- **Styling:** `Colours` palette + `Config.border` / `Tokens.rounding` via attached properties.

### Bar — `modules/bar/`

- **Purpose:** vertical bar on the **left edge** (OS icon, workspaces, active window, tray,
  clock, status icons, power button) with hover popouts.
- **Files:**
  - `BarWrapper.qml` — visibility/width animation. The bar is either persistent
    (`Config.bar.persistent`) or revealed on hover/`visibilities.bar`; sets the exclusive zone.
  - `Bar.qml` — a `ColumnLayout` built from `Config.bar.entries` through per-entry `Loader`s;
    maps hover position → popout selection (`checkPopout`) and wheel → workspace/volume.
  - `components/` — `OsIcon`, `Clock`, `ActiveWindow`, `Power`, `StatusIcons` (network,
    bluetooth, audio, keyboard layout, battery…), `Tray`/`TrayItem` (`Quickshell.Services.SystemTray`),
    `workspaces/` (Hyprland workspaces with occupied/active indicators and special workspaces).
  - `popouts/` — `Wrapper.qml`/`Content.qml`/`ClipWrapper.qml` host hover popouts next to the
    bar: `Audio.qml`, `Battery.qml`, `Bluetooth.qml`, `Network.qml` (+ `WirelessPassword.qml`),
    `kblayout/`, `ActiveWindow.qml`, `TrayMenu.qml`, `LockStatus.qml`. The wrapper also has
    *detached* modes that embed `WindowInfo` (`detachedMode === "winfo"`) or a full `Nexus`
    (`detachedMode === "any"`) inside the popout area.
- **Triggered:** always loaded inside `ContentWindow`; popouts on hover (routed by
  `Interactions` → `Bar.checkPopout`).
- **Data flow:** `Hypr` (workspaces/active window/kb layout), `Audio`, `Nmcli`, `Bluetooth`
  (Quickshell), `UPower`, `SystemTray`, `Time`, `Notifs` (DND state on LockStatus).
- **Dependencies:** registers itself in `Visibilities.bars`; drives `popouts` state shared with
  `Panels`.

### Launcher — `modules/launcher/`

- **Purpose:** app launcher / command palette that slides up from the bottom-center.
- **Files:** `Wrapper.qml` (reveal animation, max-height accounting for open dashboard),
  `Content.qml` (search field + list), `ContentList.qml` (switches list type based on the
  search prefix), `AppList.qml`, `WallpaperList.qml`, `items/` (delegates: `AppItem`,
  `ActionItem`, `CalcItem`, `SchemeItem`, `VariantItem`, `WallpaperItem`), `services/`
  (`Apps.qml` — fuzzy app search over the C++ `AppDb`; `Actions.qml` — built-in actions;
  `Schemes.qml` / `M3Variants.qml` — colour scheme pickers that call the `caelestia` CLI).
- **Triggered:** `visibilities.launcher`, flipped by the `launcher` global shortcut (with an
  interrupt guard) or `caelestia-shell ipc drawers toggle launcher`. Suppressed while a
  fullscreen window is focused.
- **Data flow:** `AppDb` (C++ desktop-entry database + frecency), `Qalculator` (C++
  libqalculate wrapper) for inline math, `Wallpapers`/`Colours` for wallpaper & scheme
  actions, fuzzy matching via `utils/Searcher.qml` (`utils/scripts/fzf.js`, `fuzzysort.js`).
  App launches go through `Quickshell.execDetached`; terminal apps via `assets/wrap_term_launch.sh`.
- **Dependencies:** closes/opens via `Visibilities`; scheme/wallpaper items drive `Colours`
  and `Wallpapers`.

### Dashboard — `modules/dashboard/`

- **Purpose:** top-center info hub with four tabs: **Dash** (clock, calendar, user info,
  resource gauges, media mini-player, weather chip), **Media** (full MPRIS player with cover
  visualiser and synced lyrics), **Performance** (CPU/GPU/memory/storage/network cards with
  sparklines), **Weather** (forecast).
- **Files:** `Wrapper.qml`, `Content.qml` (tab bar + swipe view; tabs filtered by
  `Config.dashboard.show*`), `Tabs.qml`, `Dash.qml` + `dash/*`, `Media.qml` + `media/*`
  (`LyricList`, `CoverVisualiser`, …), `Performance.qml` + `performance/*`, `WeatherTab.qml`.
- **Triggered:** `visibilities.dashboard` (keybind/IPC), or hover-reveal at the top edge when
  `Config.dashboard.showOnHover` (handled in `drawers/Interactions.qml`).
- **Data flow:** `Players` (MPRIS) + C++ `Lyrics` service; C++ `Cpu`, `Gpu`, `Memory`,
  `Storage` ticking services and `NetworkUsage`; `Weather`; `Time`; `SysInfo`; profile
  picture picked via the shared `components/filedialog/FileDialog`.
- **Dependencies:** launcher reads dashboard height to size itself; `DashboardState`
  (`components/DashboardState.qml`) holds tab state.

### Sidebar — `modules/sidebar/`

- **Purpose:** right-side notification center (grouped by app, expandable, with actions and
  a DND toggle).
- **Files:** `Wrapper.qml`, `Content.qml`, `NotifDock.qml`, `NotifDockList.qml`,
  `NotifGroup.qml`, `NotifGroupList.qml`, `Notif.qml`, `NotifActionList.qml`, `Props.qml`
  (persistent expansion state).
- **Triggered:** `visibilities.sidebar` (keybind/IPC or drag from the right edge).
- **Data flow:** entirely from `services/Notifs.qml`. Opening the sidebar suppresses popup
  notifications (`Notifs.shouldShowPopup` checks sidebar visibility across screens).

### Notification popups — `modules/notifications/`

- **Purpose:** transient popup notifications, top-right.
- **Files:** `Wrapper.qml`, `Content.qml`, `Notification.qml`.
- **Triggered:** event-driven — `Notifs.popups` (no visibility bool). Quoil **is** the
  notification daemon: `services/Notifs.qml` runs a `NotificationServer`
  (`Quickshell.Services.Notifications`, i.e. it owns `org.freedesktop.Notifications` on D-Bus).
- **Data flow:** `NotifData` objects (`services/NotifData.qml`) wrap each notification and are
  persisted to `~/.local/state/caelestia/notifs.json` so they survive shell restarts.

### Session menu — `modules/session/`

- **Purpose:** power menu (logout / shutdown / hibernate / reboot) on the right edge.
- **Files:** `Wrapper.qml`, `Content.qml` (a `Column` of `SessionButton`s with keyboard
  navigation).
- **Triggered:** `visibilities.session` (keybind/IPC/drag).
- **Data flow:** icons and commands come straight from `Config.session.icons` /
  `Config.session.commands`; executed via `Quickshell.execDetached`.

### OSD — `modules/osd/`

- **Purpose:** volume/brightness slider overlay on the right edge.
- **Files:** `Wrapper.qml`, `Content.qml`.
- **Triggered:** self-triggering: `Connections` in `Wrapper.qml` watch `Audio` volume/mute,
  source volume/mute, and the active monitor's `Brightness`, call `show()` (sets
  `visibilities.osd`) and start a hide timer. Also toggleable by keybind/IPC and hover.
  Hidden while the utilities panel is open (utilities embeds the same sliders).
- **Data flow:** `Audio` (PipeWire) and `Brightness` (ddcutil/brightnessctl); wheel events
  adjust them back through the same services.

### Utilities — `modules/utilities/`

- **Purpose:** bottom-right quick-actions panel: idle-inhibitor card, screen-recorder card
  (start/stop/pause + recent recordings list with delete modal), and a row of toggles
  (game mode, etc.).
- **Files:** `Wrapper.qml`, `Content.qml`, `Background.qml`, `cards/IdleInhibit.qml`,
  `cards/Record.qml`, `cards/RecordingList.qml`, `cards/Toggles.qml`,
  `RecordingDeleteModal.qml`, plus `toasts/Toasts.qml` + `toasts/ToastItem.qml`.
- **Triggered:** `visibilities.utilities` (keybind/IPC/drag).
- **Data flow:** `Recorder` (wraps `scripts/quoil record` → **gpu-screen-recorder**),
  `IdleInhibitor` (Wayland idle-inhibit through an invisible `PanelWindow`), `GameMode`
  (Hyprland options via C++ `HyprExtras`).
- **Toasts:** `toasts/Toasts.qml` is mounted by `Panels.qml` independently of the utilities
  visibility; it renders the queue of the C++ `Toaster` singleton, which everything
  (config errors, battery monitor, game mode, IPC `toaster` target) feeds into.

### Nexus (settings app) — `modules/nexus/`

- **Purpose:** the control-center / settings application: wallpaper & style, network,
  bluetooth, audio, apps, panel (bar/dashboard/launcher/sidebar) configuration, services,
  language, updates, about.
- **Files:** `Nexus.qml` (root layout: `NavPane` + `Pages`), `NexusState.qml` (per-instance
  navigation state), `PageRegistry.qml` / `PageCompRegistry.qml` (singleton page catalogs),
  `WindowFactory.qml` (singleton that creates the window), `NavPane.qml` + `navpane/*`,
  `Pages.qml` + `pages/*` (one file per page plus subpage folders `network/`, `bluetooth/`,
  `audio/`, `apps/`, `panels/` incl. `panels/taskbar/*`, `wallandstyle/`, `services/`),
  `common/*` (row/list/page building blocks).
- **Triggered:** **on demand only** — the `nexus` global shortcut or
  `ipc nexus open` calls `WindowFactory.create()`, which instantiates a
  `FloatingWindow` (a normal Wayland window, not a layer surface) that destroys itself on
  close. A `Nexus` can also be embedded in the bar-popout area (detached mode in
  `modules/bar/popouts/Wrapper.qml`).
- **Data flow:** pages read *and write* `GlobalConfig` (saved back to `shell.json`), and drive
  `Nmcli`, `Quickshell.Bluetooth`, `Audio`/PipeWire streams, `Wallpapers`, `Colours`.

### Lock screen — `modules/lock/`

- **Purpose:** session lock: clock, profile picture, password/fingerprint auth, plus media,
  weather, resource and notification widgets on the lock surface.
- **Files:** `Lock.qml` (root: `WlSessionLock` + shortcuts + IPC target `lock`),
  `LockSurface.qml` (per-output surface), `Content.qml`, `Center.qml` + `center/*`
  (`Clock`, `ProfilePic`, `PasswordInput`, `InputField`, `StateMessage`), `Pam.qml`
  (two `PamContext`s — password and fprintd fingerprint; checks `fprintd-list`),
  `Media.qml`, `Resources.qml`, `WeatherInfo.qml` + `weather/*`, `NotifDock.qml`,
  `NotifGroup.qml`, `Fetch.qml`.
- **Triggered:** `lock`/`unlock` global shortcuts, `ipc lock lock|unlock|isLocked`, or
  idle timeout via `modules/IdleMonitors.qml` (which gets the `Lock` reference from
  `shell.qml`). Uses the `ext-session-lock` Wayland protocol.
- **Data flow:** PAM (`assets/pam.d` config), `Players`, `Weather`, `Notifs`, `SysInfo`,
  C++ system services for the resource widgets.

### Background — `modules/background/`

- **Purpose:** per-screen background window: wallpaper, music visualiser bars, optional
  desktop clock (9 configurable positions).
- **Files:** `Background.qml`, `Wallpaper.qml`, `Visualiser.qml`, `DesktopClock.qml`.
- **Triggered:** always loaded for screens with `background.enabled`; wallpaper/clock/
  visualiser individually toggled by `Config.background.*`.
- **Data flow:** `Wallpapers` (current wallpaper path from
  `~/.local/state/caelestia/wallpaper/path.txt`), `Audio.cava` (C++ `CavaProvider` FFT bars
  fed by PipeWire capture), `Time`.

### Area picker — `modules/areapicker/`

- **Purpose:** screenshot region picker (freeze-frame overlay with region selection,
  optionally clipboard-only).
- **Files:** `AreaPicker.qml` (a `LazyLoader` + IPC target `picker` with
  `open/openFreeze/openClip/openFreezeClip`), `Picker.qml`.
- **Triggered:** **IPC only** — nothing inside the shell opens it; Hyprland binds call
  the `picker` IPC target. Loaded lazily, one overlay window per screen, exclusive keyboard
  focus while open.
- **Data flow:** `ScreencopyView` for the frozen frame; hands the region off for capture.

### Window info — `modules/windowinfo/`

- **Purpose:** floating inspector for the focused window (live preview, properties, actions).
- **Files:** `WindowInfo.qml`, `Preview.qml`, `Details.qml`, `Buttons.qml`.
- **Triggered:** shown as a *detached bar popout* (`modules/bar/popouts/Wrapper.qml`,
  `detachedMode === "winfo"`); fed `Hypr.activeToplevel`.

### Root helper scopes — `modules/*.qml`

- `Shortcuts.qml` — all `CustomShortcut`s (a thin wrapper over `GlobalShortcut` with
  `appid: "caelestia"`, `components/misc/CustomShortcut.qml`; Hyprland binds reference them as
  `global, caelestia:<name>`): `nexus`, `showall`, `dashboard`, `session`, `launcher` (+
  `launcherInterrupt`), `sidebar`, `utilities`. Plus `IpcHandler`s: target **`drawers`**
  (`toggle/list/isOpen`), **`nexus`** (`open`), **`toaster`** (`info/success/warn/error`).
  All of them resolve the active monitor via `Visibilities.getForActive()` and flip bools.
- `ConfigToasts.qml` — listens to `GlobalConfig` and `TokenConfig` load/save/unknown-option
  signals → `Toaster`.
- `BatteryMonitor.qml` — UPower plug/unplug and configurable low-battery warn levels → `Toaster`.
- `IdleMonitors.qml` — builds `IdleMonitor`s from `Config.general.idle.timeouts`; actions can
  be `lock`, `unlock`, a Hyprland dispatch (e.g. `dpms off`, with Lua-Hyprland translation),
  or a command (via C++ `SessionManager` or `execDetached`). Inhibited while audio plays or
  on AC, per config.
- `GSFLoader.qml` — font loader (see above).

---

## Services layer — `services/` (QML singletons)

All `pragma Singleton`, lazily created, shared by every module:

| Singleton | Backs onto | Used by |
|-----------|-----------|---------|
| `Visibilities.qml` | — (pure state registry: monitor → `DrawerVisibilities`, monitor → bar) | Shortcuts, IPC, Interactions, every drawer |
| `Colours.qml` | `~/.local/state/caelestia/scheme.json` (written by the `caelestia scheme` CLI, watched via `FileView`), `ImageAnalyser` (C++) on the wallpaper | every visual component (M3 palette + transparency); also pushes Hyprland layer rules |
| `Audio.qml` | `Quickshell.Services.Pipewire`; hosts C++ `CavaProvider` + `BeatTracker` | OSD, bar, dashboard media, background visualiser, Nexus audio page |
| `Brightness.qml` | `ddcutil` (external monitors), `brightnessctl` (internal), `asdbctl` (Apple displays) | OSD, bar popouts |
| `Players.qml` | `Quickshell.Services.Mpris` | dashboard media, lock media, IdleMonitors (audio-inhibit) |
| `Notifs.qml` + `NotifData.qml` | `NotificationServer` (Quoil **is** the notification daemon); persists `notifs.json` | popup notifications, sidebar, lock NotifDock, bar |
| `Hypr.qml` | `Quickshell.Hyprland` + C++ `HyprExtras`/`HyprDevices` (keyboard layout, options) | drawers (fullscreen detection), bar workspaces/active window, GameMode, Colours (layer rules), IdleMonitors |
| `Nmcli.qml` | `nmcli` / `nmcli monitor` subprocesses | bar network popout, Nexus network page |
| `VPN.qml` | provider config + connect/disconnect subprocesses | utilities toggles / status icons |
| `NetworkUsage.qml` | periodic byte-counter polling into C++ `CircularBuffer`s | dashboard performance NetworkCard sparkline |
| `Wallpapers.qml` | filesystem model of the wallpaper dir (`Quoil.Models.FileSystemModel`), current path from state dir; **sets** wallpapers via the `caelestia wallpaper` CLI | background, launcher wallpaper mode, Nexus wallpaper page |
| `Weather.qml` | HTTP via C++ `Requests`: open-meteo (forecast + geocoding), ipinfo.io / bigdatacloud / nominatim (location) | dashboard weather, lock weather |
| `Time.qml` | `SystemClock` | clocks everywhere |
| `Screens.qml` | `Quickshell.screens` filtered by per-screen config | all `Variants` models |
| `Recorder.qml` | `scripts/quoil record …` → gpu-screen-recorder (checked with `pidof`) | utilities Record card |
| `GameMode.qml` | `HyprExtras.applyOptions` (bulk Hyprland options) | utilities toggles |
| `IdleInhibitor.qml` | Wayland idle-inhibit protocol | utilities IdleInhibit card, IdleMonitors |

`utils/` adds non-visual helpers: `Paths.qml` (XDG dirs — all still under `…/caelestia`),
`Icons.qml`, `Images.qml`, `Searcher.qml` (fuzzy-search base class using
`utils/scripts/fzf.js` / `fuzzysort.js`), `Strings.qml`, `SysInfo.qml` (os-release, uptime),
`NetworkConnection.qml`.

---

## C++ plugin — `plugin/src/Caelestia/` (imported as `Quoil.*`)

Built with CMake (`nix develop` shell; `run-quoil.sh` points
`NIXPKGS_QT6_QML_IMPORT_PATH` at `build/qml`). Modules:

- **`Quoil`** — `CUtils` (misc helpers), `Toaster`/`Toast` (global toast queue), `AppDb`/
  `AppEntry` (desktop-entry DB for the launcher), `Qalculator` (libqalculate), `Requests`
  (HTTP client), `ImageAnalyser` (wallpaper luminance for Colours).
- **`Quoil.Config`** — `GlobalConfig` (file-backed config singleton ←
  `~/.config/caelestia/shell.json`, per-screen override manager), `Config`/`Tokens`
  attached types, typed config objects per module (`barconfig.hpp`, `launcherconfig.hpp`, …),
  `Tokens`/`TokenConfig` design tokens (rounding, padding, spacing, sizes, animation curves,
  transparency, fonts).
- **`Quoil.Services`** — `AudioCollector` (PipeWire capture) feeding `CavaProvider` (FFT
  bars) and `BeatTracker` (BPM); `Cpu`, `Gpu`, `Memory`, `Storage`, `DiskInfo` ticking system
  monitors; `Lyrics` (synced lyrics fetch); `SessionManager`; `UsageFmt`.
- **`Quoil.Internal`** — `HyprExtras`/`HyprDevices` (extra Hyprland IPC), `CircularBuffer`,
  `SparklineItem`, `VisualiserBars`, indicator managers.
- **`Quoil.Components`** — `WavyLine`, `LazyListView`, `ButtonRow`.
- **`Quoil.Models`** — `FileSystemModel` (wallpapers, file dialog).
- **`Quoil.Images`** — `CachingImageProvider`/`ImageCacher` (cover art, notification images).
- **`Quoil.Blobs`** — SDF blob renderer (`BlobGroup`, `BlobRect`, `BlobInvertedRect`) used for
  the morphing border/panel backgrounds in `ContentWindow` and Nexus.
- **`M3Shapes`** — external dependency fetched by CMake (Material 3 shape morphing).

---

## Shared UI kit — `components/`

Material-3-styled building blocks used everywhere: `StyledRect/StyledText/StyledWindow`,
`StateLayer` (hover/press ripple), `MaterialIcon`, animation primitives (`Anim`, `CAnim`,
`AnchorAnim`, `AnimLoader` — durations/curves from `Tokens.anim`), `controls/` (~20 buttons,
sliders, switches, text fields), `containers/`, `effects/` (`Elevation`, `Colouriser`, …),
`images/` (caching image views), `filedialog/` (a complete in-shell file dialog),
`widgets/` (`CoverArt`, …), `misc/` (`CustomShortcut`, `Ref`), and the two state holders
`DrawerVisibilities.qml` and `DashboardState.qml`.

## Styling

There is deliberately **no QML theme file**. Styling comes from two live sources:

1. **`Colours`** (`services/Colours.qml`) — the Material 3 palette, generated *outside* the
   shell by the `caelestia scheme` CLI into `~/.local/state/caelestia/scheme.json` and
   hot-reloaded via `FileView.watchChanges`. Supports preview mode (launcher/Nexus scheme
   browsing), light/dark, transparency layers, and wallpaper-luminance adjustments.
2. **`Tokens` + `Config.appearance`** (C++, `Quoil.Config`) — spacing/rounding/font-size/
   animation design tokens and user config, resolved per screen through attached properties.

Components read both; nothing hardcodes colors.

---

## How it all fits together

```
Hyprland keybind (global, caelestia:launcher)      caelestia-shell ipc …
        │                                                  │
        ▼                                                  ▼
modules/Shortcuts.qml  ──────────────►  services/Visibilities.qml (per-monitor bools)
                                                           │
                                                           ▼
shell.qml ─► modules/drawers/Drawers.qml ─► ContentWindow (per screen)
                 ├─ BarWrapper ── Bar ── popouts (hover)
                 └─ Panels ── Dashboard / Launcher / Session / Sidebar /
                              Notifications / OSD / Utilities+Toasts
                                   │ read state from
                                   ▼
              services/* singletons (Audio, Notifs, Players, Hypr, Colours, …)
                                   │ backed by
                                   ▼
     PipeWire · D-Bus (UPower/BlueZ/MPRIS/tray/notifications) · Hyprland IPC ·
     nmcli · ddcutil/brightnessctl · gpu-screen-recorder · caelestia CLI ·
     scripts/quoil · open-meteo · shell.json / scheme.json / notifs.json
```

- **One window, many drawers.** Instead of one layer-shell window per widget, each screen has
  a single full-screen `drawers` window whose input mask shrink-wraps the visible UI. Panels
  "morph" out of the screen border using the C++ SDF blob renderer. This gives unified
  animations and z-ordering at the cost of the `ContentWindow` complexity.
- **State down, events up.** UI reads singleton state declaratively; user intent flows through
  `Visibilities` bools, service methods (`Audio.setVolume`, `Recorder.start`), or external
  CLIs. There are almost no direct module-to-module references — the exceptions are layout
  couplings inside `Panels.qml` (launcher avoids the dashboard, notifications avoid the
  sidebar) passed as explicit properties.
- **Config as a live database.** `shell.json` (hot-reloaded C++ `GlobalConfig`) decides which
  modules are even enabled, their entries, behavior and per-screen overrides; Nexus writes it
  back, so the settings app configures the shell through the same file the shell watches.
- **Always-loaded vs on-demand.** Always: Background, Drawers (bar + collapsed panels),
  the root helper scopes, and the `WlSessionLock` scaffolding. On demand: each drawer's
  content (loaded when first shown), bar popouts, WindowInfo, AreaPicker (LazyLoader + IPC),
  the lock surfaces (only while locked), and Nexus (window created/destroyed per use).

---

## Caveats / ambiguities

Things I could not fully verify from the repo, or that look intentional-but-surprising:

1. **External `caelestia` CLI dependency.** `services/Wallpapers.qml`, `services/Colours.qml`,
   `modules/launcher/services/Schemes.qml` and `M3Variants.qml` still `execDetached(["caelestia", …])`
   for wallpaper/scheme changes. `scripts/quoil` explicitly replaces only *some* subcommands
   (`toggle`, `record`, `clipboard`, `emoji`, `screenshot`, `pip`) of "the removed `caelestia`
   binary" — it does **not** implement `scheme` or `wallpaper`. Whether a `caelestia` binary
   is still on `PATH` (or these calls silently fail) cannot be determined from the repo.
2. **Tokens config file path.** `TokenConfig` is file-backed (it emits `loadFailed`/
   `unknownOption`, handled in `modules/ConfigToasts.qml`), and `GlobalConfig` verifiably reads
   `~/.config/caelestia/shell.json` (`plugin/src/Caelestia/Config/config.cpp`). The exact
   filename for tokens is *presumably* a sibling file, but I couldn't read
   `plugin/src/Caelestia/Config/tokens.cpp` to confirm (read permission was denied during
   analysis).
3. **Bar orientation.** The bar is currently a vertical left-edge column
   (`Bar.qml` is a `ColumnLayout`; the wrapper animates `implicitWidth`). The README's plan to
   move it to the top is not implemented yet.
4. **IPC invocation syntax** (`caelestia-shell ipc …` vs `qs -c quoil ipc …`) depends on how
   Hyprland's binds are written, which lives outside this repo (`scripts/quoil` suggests
   Hyprland config calls it directly).
