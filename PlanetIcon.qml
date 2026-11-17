import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Item {
  id: root

  property var bar: null
  property real iconSize: Style.font.icon
  property color planetColor: Commons.Color.accent
  property color ringColor: bar ? bar.barForeground : Commons.Color.foreground
  property bool isBusy: false
  property bool active: false

  // Combined busy state for bar indicator & progress animations
  readonly property bool busy: isBusy || active

  implicitWidth: iconSize
  implicitHeight: iconSize
  width: iconSize
  height: iconSize

  function requestPaint() {
    canvas.requestPaint()
  }

  onPlanetColorChanged: requestPaint()
  onRingColorChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()
  onBusyChanged: requestPaint()

  // Gentle breathing / pulse animation when busy installing
  property real pulseScale: 1.0

  SequentialAnimation {
    id: pulseAnim
    running: root.busy && !Style.reduceMotion
    loops: Animation.Infinite

    NumberAnimation {
      target: root
      property: "pulseScale"
      to: 1.14
      duration: Style.duration(700)
      easing.type: Easing.InOutSine
    }
    NumberAnimation {
      target: root
      property: "pulseScale"
      to: 0.94
      duration: Style.duration(700)
      easing.type: Easing.InOutSine
    }
    onStopped: root.pulseScale = 1.0
  }

  // Smooth orbital light sweep when busy
  property real busyAngle: 0
  NumberAnimation {
    id: rotAnim
    running: root.busy && !Style.reduceMotion
    loops: Animation.Infinite
    target: root
    property: "busyAngle"
    from: 0
    to: 360
    duration: Style.duration(2400)
    onStopped: root.busyAngle = 0
  }

  Canvas {
    id: canvas
    anchors.centerIn: parent
    width: root.width
    height: root.height
    scale: root.busy ? root.pulseScale : 1.0

    onPaint: {
      var ctx = getContext("2d");
      ctx.reset();

      var w = width;
      var h = height;
      var cx = w / 2;
      var cy = h / 2;
      // Reserve 1px margin around sphere so anti-aliasing doesn't clip
      var r = Math.max(2, (Math.min(w, h) / 2) - 1.2);

      // -------------------------------------------------------------------
      // 1. Base Celestial Sphere with 3D Spherical Radial Shading
      // -------------------------------------------------------------------
      ctx.save();
      var lightAngle = root.busy ? ((-0.75 * Math.PI) + (root.busyAngle * Math.PI / 180)) : (-0.75 * Math.PI);
      var lightDist = r * 0.45;
      var lx = cx + Math.cos(lightAngle) * lightDist;
      var ly = cy + Math.sin(lightAngle) * lightDist;

      var grad = ctx.createRadialGradient(lx, ly, r * 0.08, cx, cy, r);
      grad.addColorStop(0.0, Qt.lighter(root.planetColor, 1.25));
      grad.addColorStop(0.45, root.planetColor);
      grad.addColorStop(0.82, Qt.darker(root.planetColor, 1.45));
      grad.addColorStop(1.0, Qt.darker(root.planetColor, 2.1));

      ctx.fillStyle = grad;
      ctx.beginPath();
      ctx.arc(cx, cy, r, 0, 2 * Math.PI);
      ctx.fill();
      ctx.restore();

      // -------------------------------------------------------------------
      // 2. Planet Surface Features (Craters & Maria / Terrain Texture)
      // -------------------------------------------------------------------
      ctx.save();
      ctx.beginPath();
      ctx.arc(cx, cy, r, 0, 2 * Math.PI);
      ctx.clip();

      // Mare / terrain depth band across equatorial region
      ctx.beginPath();
      ctx.fillStyle = Qt.rgba(0, 0, 0, 0.09);
      ctx.ellipse(cx, cy - r * 0.1, r * 0.88, r * 0.32, -0.22, 0, 2 * Math.PI);
      ctx.fill();

      // Distinct crater features (scaled dynamically to resolution)
      function drawCrater(ox, oy, rad) {
        // Shadow cavity
        ctx.beginPath();
        ctx.fillStyle = Qt.rgba(0, 0, 0, 0.22);
        ctx.arc(ox, oy, rad, 0, 2 * Math.PI);
        ctx.fill();

        // Illuminated rim (sunlit crest)
        ctx.beginPath();
        ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.35);
        ctx.lineWidth = Math.max(0.65, rad * 0.28);
        ctx.arc(ox, oy, Math.max(0.2, rad - 0.2), Math.PI * 0.75, Math.PI * 1.75);
        ctx.stroke();
      }

      if (r >= 6.5) {
        drawCrater(cx - r * 0.36, cy + r * 0.16, r * 0.22);
        drawCrater(cx + r * 0.26, cy - r * 0.32, r * 0.16);
        drawCrater(cx + r * 0.16, cy + r * 0.42, r * 0.14);
        drawCrater(cx - r * 0.10, cy - r * 0.44, r * 0.12);
      } else if (r >= 4.0) {
        // Small bar icon representation: 2 prominent craters
        drawCrater(cx - r * 0.32, cy + r * 0.15, r * 0.24);
        drawCrater(cx + r * 0.28, cy - r * 0.28, r * 0.18);
      }
      ctx.restore();

      // -------------------------------------------------------------------
      // 3. Realistic Day/Night Terminator & Crescent Shadow
      // -------------------------------------------------------------------
      ctx.save();
      ctx.beginPath();
      ctx.arc(cx, cy, r, 0, 2 * Math.PI);
      ctx.clip();

      var sx = cx - Math.cos(lightAngle) * r;
      var sy = cy - Math.sin(lightAngle) * r;
      var shadowGrad = ctx.createLinearGradient(lx, ly, sx, sy);
      shadowGrad.addColorStop(0.0, Qt.rgba(0, 0, 0, 0));
      shadowGrad.addColorStop(0.42, Qt.rgba(0, 0, 0, 0));
      shadowGrad.addColorStop(0.72, Qt.rgba(0, 0, 0, 0.32));
      shadowGrad.addColorStop(1.0, Qt.rgba(0, 0, 0, 0.68));

      ctx.fillStyle = shadowGrad;
      ctx.beginPath();
      ctx.arc(cx, cy, r, 0, 2 * Math.PI);
      ctx.fill();
      ctx.restore();

      // -------------------------------------------------------------------
      // 4. Specular Atmospheric Highlight (Sunlit Gleam)
      // -------------------------------------------------------------------
      ctx.save();
      ctx.beginPath();
      ctx.arc(cx, cy, r, 0, 2 * Math.PI);
      ctx.clip();

      var specGrad = ctx.createRadialGradient(lx, ly, 0, lx, ly, r * 0.65);
      specGrad.addColorStop(0.0, Qt.rgba(1, 1, 1, 0.42));
      specGrad.addColorStop(0.45, Qt.rgba(1, 1, 1, 0.12));
      specGrad.addColorStop(1.0, Qt.rgba(1, 1, 1, 0.0));

      ctx.fillStyle = specGrad;
      ctx.beginPath();
      ctx.arc(cx, cy, r, 0, 2 * Math.PI);
      ctx.fill();
      ctx.restore();

      // -------------------------------------------------------------------
      // 5. Sunlit Limb Arc (Crisp Celestial Outline on Sun Side)
      // -------------------------------------------------------------------
      ctx.save();
      ctx.beginPath();
      ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.55);
      ctx.lineWidth = Math.max(0.75, Math.min(1.5, w * 0.05));
      var arcCenter = lightAngle;
      ctx.arc(cx, cy, r - 0.5, arcCenter - 0.7, arcCenter + 0.7);
      ctx.stroke();
      ctx.restore();
    }
  }

  Component.onCompleted: requestPaint()
}
