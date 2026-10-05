import QtQuick
import QtQuick.Shapes

// Outline of anything docked to the bar, drawn hanging from the top edge; rotate it for the
// others. A concave corner peels each side off the edge, the side runs straight down at
// `Config.dockSlope`, and a convex corner turns it into the flat floor that holds the content.
Shape {
    id: dock

    required property real length   // flat stretch of the floor between the two lower corners
    required property real depth    // how far the dock reaches into the screen

    readonly property real slope: Math.max(0, Config.dockSlope)
    // The sides' lean as an angle away from vertical.
    readonly property real lean: Math.atan(slope)
    // Shrunk when the two corners on a side wouldn't both fit within the depth.
    readonly property real radius: Math.min(Math.max(0, Config.dockRadius), depth / 2 / (1 - Math.sin(lean)))

    // How far each corner's arc reaches across and down before handing over to the side.
    readonly property real arcX: radius * Math.cos(lean)
    readonly property real arcY: radius * (1 - Math.sin(lean))

    // Width of each side, from leaving the edge to meeting the floor: two corners and the
    // straight run between them.
    readonly property real shoulder: 2 * arcX + slope * (depth - 2 * arcY)
    readonly property real span: length + 2 * shoulder

    implicitWidth: span
    implicitHeight: depth
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: Config.barColour
        strokeColor: "transparent"

        startX: 0
        startY: 0

        PathArc {
            x: dock.arcX
            y: dock.arcY
            radiusX: dock.radius
            radiusY: dock.radius
        }
        PathLine {
            x: dock.shoulder - dock.arcX
            y: dock.depth - dock.arcY
        }
        PathArc {
            x: dock.shoulder
            y: dock.depth
            radiusX: dock.radius
            radiusY: dock.radius
            direction: PathArc.Counterclockwise
        }
        PathLine {
            x: dock.span - dock.shoulder
            y: dock.depth
        }
        PathArc {
            x: dock.span - dock.shoulder + dock.arcX
            y: dock.depth - dock.arcY
            radiusX: dock.radius
            radiusY: dock.radius
            direction: PathArc.Counterclockwise
        }
        PathLine {
            x: dock.span - dock.arcX
            y: dock.arcY
        }
        PathArc {
            x: dock.span
            y: 0
            radiusX: dock.radius
            radiusY: dock.radius
        }
        PathLine {
            x: 0
            y: 0
        }
    }
}
