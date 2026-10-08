# quoil

A deliberately minimal Quickshell config: a wallpaper and a clock bar. Nothing else.

The bar is invisible along its whole edge except the middle, where it curves smoothly into
the screen and back out to hold a clock. `Config.barEdge` picks the edge it hangs from.

`Config.barScale` controls the overall status bar size, including the clock and rounded
corners: `1.0` is the default, `1.5` is 50% larger, and `0.75` is 25% smaller (minimum
`0.1`). `barThickness` and `barLength` set the base dimensions before scaling.
The bar reserves its scaled thickness along the selected screen edge, so Hyprland
tiled windows resize to fit without overlapping it.

**No build step.** Unlike `mycaelestia` (a Caelestia fork with a custom C++ plugin that has
to be compiled), quoil imports only stock `QtQuick`, `Quickshell` and `Quickshell.Wayland`.
Clone it, run it, done.

## Run

```sh
./run-quoil.sh          # or: qs -c quoil
```

Or switch to it from whatever shell is running:

```sh
~/.config/quickshell/shellctl use quoil
```

## Files

| file | what it does |
|---|---|
| `Config.qml` | **The one file to edit.** Wallpaper, bar edge, dip size, dock slope and corner radius, colours. |
| `Background.qml` | Fullscreen wallpaper on the `Background` layer, one per monitor. |
| `Bar.qml` | Holds the clock's dip, rotated to whichever edge it hangs from. Reserves its scaled thickness. |
| `DockShape.qml` | Outline shared by everything docked to the bar: rounded corners off the edge, sides at `dockSlope`, rounded corners onto a flat floor. |
| `Clock.qml` | `hh:mm`, stacked onto two lines on the left/right edges. |
| `shell.qml` | Entry point. Fans both of the above out over `Quickshell.screens`. |
| `run-quoil.sh` | Thin `qs -c quoil` wrapper. |

`shell.qml` sets `settings.watchFiles: true`, so saving any of these reloads the shell live —
no restart needed while you're building it out.

There are no `qmldir` files because Quickshell generates them: `pragma Singleton` plus
same-directory filenames is all the module wiring this needs.
