import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Item {
  id: root

  // External bindings
  property var service: null
  property var panel: null
  property var bar: panel ? panel.bar : null

  // Theme palette bindings
  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property color accent: Commons.Color.accent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color popupsBackground: Commons.Color.popups.background
  readonly property color popupsBorder: Commons.Color.popups.border
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // Signals
  signal closeRequested()
  signal fileSelected(string path)

  // Internal state fallbacks (when service is not attached or standalone)
  property string internalState: "idle"
  property int internalStep: 1
  property string internalStatusMessage: ""
  property string internalCandidateName: ""
  property string internalErrorMessage: ""
  property var internalAppDetails: ({
    name: "Application",
    categories: "Utility",
    binaryPath: "~/.local/share/appimages/app.AppImage",
    desktopPath: "~/.local/share/applications/appimage_app.desktop",
    iconPath: ""
  })

  // State resolution
  readonly property string currentState: service && service.state ? service.state : internalState
  readonly property bool isInstalling: currentState === "installing" || currentState === "processing"
  readonly property int currentStep: {
    if (service && service.progress !== undefined) {
      if (service.progress >= 0.85) return 4
      if (service.progress >= 0.65) return 3
      if (service.progress >= 0.35) return 2
      return 1
    }
    return internalStep
  }

  readonly property string statusMessage: {
    if (service && service.currentStep) return service.currentStep
    if (internalStatusMessage) return internalStatusMessage
    return "Processing installation..."
  }

  readonly property string candidateName: {
    if (service && service.selectedFilePath) {
      var p = service.selectedFilePath
      var base = p.substring(p.lastIndexOf("/") + 1)
      return base.replace(/\.AppImage$/i, "")
    }
    return internalCandidateName
  }

  readonly property string errorMessage: service && service.errorMessage ? service.errorMessage : internalErrorMessage
  readonly property var appDetails: service && service.installedApp ? service.installedApp : internalAppDetails

  implicitWidth: Style.space(380)
  implicitHeight: mainLayout.implicitHeight + (padding * 2)

  property int padding: Style.spacing.popupPadding

  // -------------------------------------------------------------------------
  // Interaction Methods
  // -------------------------------------------------------------------------

  function closePanel() {
    root.closeRequested()
    if (panel && typeof panel.close === "function") {
      panel.close()
    } else if (root.parent && typeof root.parent.close === "function") {
      root.parent.close()
    }
  }

  function selectFile() {
    if (service && typeof service.pickAndInstall === "function") {
      service.pickAndInstall()
    } else if (service && typeof service.openFileDialog === "function") {
      service.openFileDialog()
    } else if (service && typeof service.selectFile === "function") {
      service.selectFile()
    } else {
      zenityProcess.running = true
    }
  }

  function installAppImage(filePath) {
    if (!filePath || filePath.trim() === "") return
    var cleanPath = filePath.trim()
    if (cleanPath.startsWith("file://")) {
      cleanPath = decodeURIComponent(cleanPath.substring(7))
    }
    root.fileSelected(cleanPath)

    if (service && typeof service.installApp === "function") {
      service.installApp(cleanPath)
    } else if (service && typeof service.install === "function") {
      service.install(cleanPath)
    } else {
      // Standalone simulation fallback
      var base = cleanPath.substring(cleanPath.lastIndexOf("/") + 1)
      internalCandidateName = base.replace(/\.AppImage$/i, "")
      internalState = "installing"
      internalStep = 1
      internalStatusMessage = "Validating AppImage binary..."
      stepTimer.restart()
    }
  }

  function launchApp() {
    if (service && typeof service.launchInstalledApp === "function") {
      service.launchInstalledApp()
    } else if (service && typeof service.launchApp === "function") {
      service.launchApp()
    } else if (appDetails && appDetails.binaryPath) {
      Quickshell.execDetached([appDetails.binaryPath])
    }
  }

  function openFolder() {
    if (service && typeof service.openAppImageFolder === "function") {
      service.openAppImageFolder()
    } else if (service && typeof service.openFolder === "function") {
      service.openFolder()
    } else {
      var dest = Quickshell.env("HOME") + "/.local/share/appimages"
      Quickshell.execDetached(["xdg-open", dest])
    }
  }

  function reset() {
    if (service && typeof service.reset === "function") {
      service.reset()
    }
    internalState = "idle"
    internalStep = 1
    internalStatusMessage = ""
    internalCandidateName = ""
    internalErrorMessage = ""
  }

  // Fallback standalone simulator timer
  Timer {
    id: stepTimer
    interval: 800
    repeat: false
    onTriggered: {
      if (root.internalStep === 1) {
        root.internalStep = 2
        root.internalStatusMessage = "Extracting high-resolution icon & metadata..."
        stepTimer.restart()
      } else if (root.internalStep === 2) {
        root.internalStep = 3
        root.internalStatusMessage = "Installing binary to ~/.local/share/appimages..."
        stepTimer.restart()
      } else if (root.internalStep === 3) {
        root.internalStep = 4
        root.internalStatusMessage = "Registering with Omarchy menu..."
        stepTimer.restart()
      } else {
        root.internalState = "success"
        root.internalAppDetails = {
          name: root.internalCandidateName || "AppImage Application",
          categories: "Utility;Applications;",
          binaryPath: Quickshell.env("HOME") + "/.local/share/appimages/" + root.internalCandidateName + ".AppImage",
          desktopPath: Quickshell.env("HOME") + "/.local/share/applications/appimage_app.desktop",
          iconPath: ""
        }
      }
    }
  }

  // Zenity file chooser process
  Process {
    id: zenityProcess
    running: false
    command: [
      "zenity",
      "--file-selection",
      "--title=Select .AppImage",
      "--file-filter=AppImage files (*.AppImage *.appimage) | *.AppImage *.appimage *.APPIMAGE",
      "--file-filter=All files | *"
    ]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: function() {
        var path = text.trim()
        if (path.length > 0) {
          root.installAppImage(path)
        }
      }
    }
  }

  // -------------------------------------------------------------------------
  // UI Layout
  // -------------------------------------------------------------------------

  ColumnLayout {
    id: mainLayout
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: root.padding
    spacing: Style.spacing.md

    // -----------------------------------------------------------------------
    // Header Row
    // -----------------------------------------------------------------------
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.spacing.sm

      PlanetIcon {
        id: headerPlanetIcon
        bar: root.bar
        iconSize: Style.space(22)
        isBusy: root.isInstalling
        Layout.alignment: Qt.AlignVCenter
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        Text {
          text: "Mercury"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodyLarge || Style.space(15)
          font.bold: true
          elide: Text.ElideRight
        }

        Text {
          text: "AppImage Installer"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }

      PanelActionButton {
        iconText: "󰅖"
        tooltipText: "Close"
        foreground: root.foreground
        fontFamily: root.fontFamily
        Layout.alignment: Qt.AlignVCenter
        onClicked: root.closePanel()
      }
    }

    PanelSeparator {
      foreground: root.foreground
      Layout.fillWidth: true
    }

    // -----------------------------------------------------------------------
    // View 1: IDLE STATE
    // -----------------------------------------------------------------------
    ColumnLayout {
      id: idleView
      visible: root.currentState === "idle" || root.currentState === "selecting"
      Layout.fillWidth: true
      spacing: Style.spacing.md

      // Large dashed drop zone
      Rectangle {
        id: dropZone
        Layout.fillWidth: true
        implicitHeight: Style.space(160)
        radius: Style.cornerRadius > 0 ? Style.cornerRadius : Style.space(10)
        color: dropArea.containsDrag
          ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.12)
          : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.03)

        border.color: dropArea.containsDrag
          ? root.accent
          : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.22)
        border.width: dropArea.containsDrag ? 2 : 1

        Behavior on color {
          ColorAnimation { duration: Style.duration(150) }
        }
        Behavior on border.color {
          ColorAnimation { duration: Style.duration(150) }
        }

        DropArea {
          id: dropArea
          anchors.fill: parent

          onEntered: function(drag) {
            if (drag.hasUrls || drag.hasText) drag.accept()
          }

          onDropped: function(drop) {
            var path = ""
            if (drop.hasUrls && drop.urls.length > 0) {
              path = String(drop.urls[0])
            } else if (drop.hasText && drop.text.length > 0) {
              path = String(drop.text)
            }
            if (path !== "") {
              root.installAppImage(path)
            }
          }
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.selectFile()
        }

        ColumnLayout {
          anchors.centerIn: parent
          spacing: Style.spacing.xs

          Text {
            text: "󰉋"
            color: dropArea.containsDrag ? root.accent : root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.space(36)
            horizontalAlignment: Text.AlignHCenter
            Layout.alignment: Qt.AlignHCenter

            Behavior on color {
              ColorAnimation { duration: Style.duration(150) }
            }
          }

          Text {
            text: "Drag & drop .AppImage here"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            Layout.alignment: Qt.AlignHCenter
          }

          Text {
            text: "or click anywhere to browse"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignHCenter
            Layout.alignment: Qt.AlignHCenter
          }
        }
      }

      // Primary Action Button
      Button {
        text: "Select .AppImage"
        iconText: "󰉋"
        bordered: true
        accent: root.accent
        foreground: root.foreground
        fontFamily: root.fontFamily
        horizontalPadding: Style.space(20)
        verticalPadding: Style.space(8)
        Layout.alignment: Qt.AlignHCenter
        onClicked: root.selectFile()
      }

      Text {
        text: "Installed apps appear automatically in the Omarchy menu & dock with high-res icons."
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
        Layout.topMargin: Style.space(2)
      }
    }

    // -----------------------------------------------------------------------
    // View 2: INSTALLING / PROCESSING STATE
    // -----------------------------------------------------------------------
    ColumnLayout {
      id: installingView
      visible: root.isInstalling
      Layout.fillWidth: true
      spacing: Style.spacing.md

      Item {
        implicitHeight: Style.space(8)
      }

      // Animated planet spinner & hero title
      PlanetIcon {
        bar: root.bar
        iconSize: Style.space(48)
        isBusy: true
        Layout.alignment: Qt.AlignHCenter
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(2)

        Text {
          text: root.candidateName !== "" ? ("Installing " + root.candidateName) : "Installing AppImage..."
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
          horizontalAlignment: Text.AlignHCenter
          Layout.alignment: Qt.AlignHCenter
          elide: Text.ElideRight
        }

        Text {
          text: root.statusMessage !== "" ? root.statusMessage : "Configuring package and registering launcher..."
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          horizontalAlignment: Text.AlignHCenter
          Layout.alignment: Qt.AlignHCenter
          elide: Text.ElideRight
        }
      }

      // Progress bar
      Rectangle {
        Layout.fillWidth: true
        height: Style.space(4)
        radius: height / 2
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.1)

        Rectangle {
          id: progressBarFill
          height: parent.height
          radius: height / 2
          color: root.accent
          width: {
            if (root.service && root.service.progress !== undefined) {
              return parent.width * Math.max(0.1, Math.min(1.0, root.service.progress))
            }
            var step = Math.max(1, Math.min(4, root.currentStep))
            return parent.width * (step / 4.0)
          }

          Behavior on width {
            NumberAnimation { duration: Style.duration(280); easing.type: Easing.OutQuad }
          }
        }
      }

      // Stepper list
      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.spacing.xs

        Repeater {
          model: [
            { step: 1, label: "Validating binary permissions and format" },
            { step: 2, label: "Extracting application metadata and original icon" },
            { step: 3, label: "Installing binary to ~/.local/share/appimages" },
            { step: 4, label: "Registering desktop launcher with Omarchy menu" }
          ]

          delegate: RowLayout {
            Layout.fillWidth: true
            spacing: Style.spacing.sm

            readonly property bool isDone: root.currentStep > modelData.step
            readonly property bool isCurrent: root.currentStep === modelData.step

            Text {
              text: isDone ? "󰄬" : (isCurrent ? "󰑮" : "󰄰")
              color: isDone ? root.accent : (isCurrent ? root.accent : root.dim)
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              Layout.alignment: Qt.AlignVCenter

              NumberAnimation on rotation {
                running: isCurrent && !Style.reduceMotion
                from: 0
                to: 360
                duration: Style.duration(1200)
                loops: Animation.Infinite
              }
            }

            Text {
              text: modelData.label
              color: isCurrent ? root.foreground : (isDone ? root.foreground : root.dim)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: isCurrent
              elide: Text.ElideRight
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
            }
          }
        }
      }

      Item {
        implicitHeight: Style.space(6)
      }
    }

    // -----------------------------------------------------------------------
    // View 3: SUCCESS STATE
    // -----------------------------------------------------------------------
    ColumnLayout {
      id: successView
      visible: root.currentState === "success"
      Layout.fillWidth: true
      spacing: Style.spacing.md

      // Success Banner
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.spacing.sm

        Text {
          text: "󰄬"
          color: root.accent
          font.family: root.fontFamily
          font.pixelSize: Style.space(22)
          font.bold: true
          Layout.alignment: Qt.AlignVCenter
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 0

          Text {
            text: "Installed Successfully!"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodyLarge || Style.space(15)
            font.bold: true
          }

          Text {
            text: "Application is ready in your menu and dock."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }

      // Application Details Card
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: appDetailsRow.implicitHeight + Style.space(16)
        radius: Style.cornerRadius > 0 ? Style.cornerRadius : Style.space(8)
        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.04)
        border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
        border.width: 1

        RowLayout {
          id: appDetailsRow
          anchors.fill: parent
          anchors.margins: Style.space(10)
          spacing: Style.spacing.md

          // Extracted Icon Preview
          Rectangle {
            width: Style.space(56)
            height: Style.space(56)
            radius: Style.space(8)
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.06)
            clip: true
            Layout.alignment: Qt.AlignVCenter

            Image {
              id: appIconImage
              anchors.fill: parent
              anchors.margins: Style.space(4)
              source: root.appDetails && root.appDetails.iconPath ? ("file://" + root.appDetails.iconPath) : ""
              fillMode: Image.PreserveAspectFit
              smooth: true
              mipmap: true
              visible: status === Image.Ready
            }

            Text {
              anchors.centerIn: parent
              visible: !appIconImage.visible
              text: "󰘵"
              color: root.accent
              font.family: root.fontFamily
              font.pixelSize: Style.space(28)
            }
          }

          // Details info
          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.space(2)

            Text {
              text: (root.appDetails && root.appDetails.name) ? root.appDetails.name : "AppImage App"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              font.bold: true
              elide: Text.ElideRight
              Layout.fillWidth: true
            }

            Text {
              text: (root.appDetails && root.appDetails.categories) ? root.appDetails.categories : "Utility"
              color: root.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
              Layout.fillWidth: true
            }

            Text {
              text: (root.appDetails && root.appDetails.binaryPath) ? root.appDetails.binaryPath : "~/.local/share/appimages"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideMiddle
              Layout.fillWidth: true
            }
          }
        }
      }

      // Action Buttons
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.spacing.sm

        Button {
          text: "Launch"
          iconText: "󰐊"
          selected: true
          accent: root.accent
          foreground: root.foreground
          fontFamily: root.fontFamily
          horizontalPadding: Style.space(14)
          Layout.fillWidth: true
          onClicked: root.launchApp()
        }

        Button {
          text: "Folder"
          iconText: "󰉋"
          bordered: true
          foreground: root.foreground
          fontFamily: root.fontFamily
          horizontalPadding: Style.space(12)
          onClicked: root.openFolder()
        }

        Button {
          text: "Install Another"
          iconText: "󰑮"
          bordered: true
          foreground: root.foreground
          fontFamily: root.fontFamily
          horizontalPadding: Style.space(12)
          onClicked: root.reset()
        }
      }
    }

    // -----------------------------------------------------------------------
    // View 4: ERROR STATE
    // -----------------------------------------------------------------------
    ColumnLayout {
      id: errorView
      visible: root.currentState === "error"
      Layout.fillWidth: true
      spacing: Style.spacing.md

      Item {
        implicitHeight: Style.space(4)
      }

      Text {
        text: "󰅚"
        color: Commons.Color.urgent
        font.family: root.fontFamily
        font.pixelSize: Style.space(36)
        horizontalAlignment: Text.AlignHCenter
        Layout.alignment: Qt.AlignHCenter
      }

      Text {
        text: "Installation Failed"
        color: Commons.Color.urgent
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodyLarge || Style.space(15)
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        Layout.alignment: Qt.AlignHCenter
      }

      // Error message container
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: errorText.implicitHeight + Style.space(16)
        radius: Style.cornerRadius > 0 ? Style.cornerRadius : Style.space(8)
        color: Qt.rgba(Commons.Color.urgent.r, Commons.Color.urgent.g, Commons.Color.urgent.b, 0.08)
        border.color: Qt.rgba(Commons.Color.urgent.r, Commons.Color.urgent.g, Commons.Color.urgent.b, 0.3)
        border.width: 1

        Text {
          id: errorText
          anchors.fill: parent
          anchors.margins: Style.space(10)
          text: root.errorMessage !== "" ? root.errorMessage : "The selected file is not a valid AppImage or an extraction error occurred."
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
        }
      }

      RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: Style.spacing.md

        Button {
          text: "Try Again"
          iconText: "󰑮"
          bordered: true
          accent: root.accent
          foreground: root.foreground
          fontFamily: root.fontFamily
          horizontalPadding: Style.space(18)
          onClicked: root.reset()
        }

        Button {
          text: "Close"
          iconText: "󰅖"
          bordered: true
          foreground: root.foreground
          fontFamily: root.fontFamily
          horizontalPadding: Style.space(16)
          onClicked: root.closePanel()
        }
      }
    }
  }
}
