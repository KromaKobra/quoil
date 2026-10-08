import QtQuick
import Quickshell
import Quickshell.Hyprland

WheelHandler {
    id: handler

    required property ShellScreen screen
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property int activeWorkspace: monitor?.activeWorkspace?.id ?? 0
    readonly property int workspaceCount: 10
    property real remainder: 0

    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    target: null

    function activateWorkspace(workspaceId: int): void {
        if (!monitor)
            return;
        if (Hyprland.focusedMonitor !== monitor)
            Hyprland.dispatch("focusmonitor " + monitor.name);
        Hyprland.dispatch("workspace " + workspaceId);
    }

    function cycleWorkspaces(steps: int): void {
        const current = activeWorkspace >= 1 && activeWorkspace <= workspaceCount ? activeWorkspace : 1;
        activateWorkspace(((current - 1 + steps) % workspaceCount + workspaceCount) % workspaceCount + 1);
    }

    onActiveChanged: {
        if (!active)
            remainder = 0;
    }
    onWheel: event => {
        const delta = event.angleDelta.y || event.angleDelta.x;
        remainder += delta ? delta / 120 : (event.pixelDelta.y || event.pixelDelta.x) / 40;
        const steps = Math.trunc(remainder);
        if (steps !== 0) {
            remainder -= steps;
            cycleWorkspaces(-steps);
        }
        event.accepted = true;
    }
}
