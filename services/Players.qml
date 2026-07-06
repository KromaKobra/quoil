pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quoil
import Quoil.Config
import qs.components.misc
import qs.utils

Singleton {
    id: root

    readonly property list<MprisPlayer> list: Mpris.players.values
    readonly property MprisPlayer active: props.manualActive ?? list.find(p => getIdentity(p) === GlobalConfig.services.defaultPlayer) ?? list[0] ?? null
    property alias manualActive: props.manualActive

    // Fable code to fix crashes [START]
    readonly property string artUrl: getArtUrl(active)
    // Local (or empty) source for the active player's cover art. Remote art is
    // downloaded with curl instead of being loaded directly by Image, as Qt 6.11's
    // HTTP/2 client segfaults on https image loads.
    property string artSource

    onArtUrlChanged: updateArtSource()
    Component.onCompleted: updateArtSource()

    function updateArtSource(): void {
        const url = artUrl;
        if (!url.startsWith("http://") && !url.startsWith("https://")) {
            artSource = url;
            return;
        }

        artSource = "";
        artDownloader.running = false;
        artDownloader.url = url;
        artDownloader.path = `${Paths.imagecache}/mpris/${Qt.md5(url)}`;
        artDownloader.running = true;
    }
    // Fable code to fix crashes [END]

    function getIdentity(player: MprisPlayer): string {
        if (!player)
            return "";
        const alias = GlobalConfig.services.playerAliases.find(a => a.from === player.identity);
        return alias?.to ?? player.identity;
    }

    function getArtUrl(player: MprisPlayer): string {
        if (!player)
            return "";
        if (player.trackArtUrl)
            return player.trackArtUrl;

        const url = player.metadata["xesam:url"] ?? "";
        if (url.startsWith("https://www.youtube.com/watch")) {
            // Fallback for youtube
            const id = url.match(/[?&]v=([\w-]{11})/)?.[1];
            return id ? `https://img.youtube.com/vi/${id}/hqdefault.jpg` : "";
        }
        return "";
    }

    Connections {
        function onPostTrackChanged() {
            if (!GlobalConfig.utilities.toasts.nowPlaying) {
                return;
            }
            if (root.active.trackArtist != "" && root.active.trackTitle != "") {
                Toaster.toast(qsTr("Now Playing"), qsTr("%1 - %2").arg(root.active.trackArtist).arg(root.active.trackTitle), "music_note");
            }
        }

        target: root.active
    }

    Process { // ADDED BY FABLE TO SOLVE SHELL CRASHES. Should review to understand what has changed.
        id: artDownloader

        property string url
        property string path

        command: ["sh", "-c", `[ -f "$0" ] || { mkdir -p "$(dirname "$0")" && curl -sSfL --max-time 15 -o "$0.part" "$1" && mv "$0.part" "$0"; }`, path, url]
        onExited: exitCode => {
            if (exitCode === 0 && url === root.artUrl)
                root.artSource = `file://${path}`;
        }
    }

    PersistentProperties {
        id: props

        property MprisPlayer manualActive

        reloadableId: "players"
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "mediaToggle"
        description: "Toggle media playback"
        onPressed: {
            const active = root.active;
            if (active && active.canTogglePlaying)
                active.togglePlaying();
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "mediaPrev"
        description: "Previous track"
        onPressed: {
            const active = root.active;
            if (active && active.canGoPrevious)
                active.previous();
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "mediaNext"
        description: "Next track"
        onPressed: {
            const active = root.active;
            if (active && active.canGoNext)
                active.next();
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "mediaStop"
        description: "Stop media playback"
        onPressed: root.active?.stop()
    }

    IpcHandler {
        function getActive(prop: string): string {
            const active = root.active;
            return active ? active[prop] ?? "Invalid property" : "No active player";
        }

        function list(): string {
            return root.list.map(p => root.getIdentity(p)).join("\n");
        }

        function play(): void {
            const active = root.active;
            if (active?.canPlay)
                active.play();
        }

        function pause(): void {
            const active = root.active;
            if (active?.canPause)
                active.pause();
        }

        function playPause(): void {
            const active = root.active;
            if (active?.canTogglePlaying)
                active.togglePlaying();
        }

        function previous(): void {
            const active = root.active;
            if (active?.canGoPrevious)
                active.previous();
        }

        function next(): void {
            const active = root.active;
            if (active?.canGoNext)
                active.next();
        }

        function stop(): void {
            root.active?.stop();
        }

        target: "mpris"
    }
}
