import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons as Commons
import qs.Commons

Item {
  id: root

  property var settings: null
  readonly property string configuredDir: settings && settings.installDirectory ? settings.installDirectory : "~/.local/share/appimages"
  property string installDirectory: configuredDir

  // States: "idle" | "selecting" | "installing" | "success" | "error"
  property string state: "idle"
  property string currentStep: ""
  property real progress: 0.0
  property string selectedFilePath: ""
  property string errorMessage: ""
  property var installedApp: null

  readonly property string scriptPath: {
    var u = Qt.resolvedUrl("scripts/mercury-install.sh").toString()
    if (u.indexOf("file://") === 0) return decodeURIComponent(u.substring(7))
    return u
  }

  signal installFinished(var appInfo)
  signal installFailed(string error)

  function reset() {
    state = "idle"
    currentStep = ""
    progress = 0.0
    selectedFilePath = ""
    errorMessage = ""
    installedApp = null
  }

  function pickAndInstall() {
    if (state === "installing") return
    state = "selecting"
    pickerProcess.running = false
    pickerProcess.running = true
  }

  function installApp(filePath) {
    if (!filePath || String(filePath).trim().length === 0) {
      state = "error"
      errorMessage = "No file selected."
      return
    }

    var cleanPath = String(filePath).trim()
    // Handle file:// URI if passed from drag-and-drop
    if (cleanPath.indexOf("file://") === 0) {
      cleanPath = decodeURIComponent(cleanPath.substring(7))
    }

    selectedFilePath = cleanPath
    state = "installing"
    currentStep = "Validating AppImage binary..."
    progress = 0.2

    installProcess.command = [
      root.scriptPath,
      cleanPath,
      root.installDirectory
    ]
    installProcess.running = false
    installProcess.running = true
    progressTimer.restart()
  }

  function launchInstalledApp() {
    if (!installedApp) return
    if (installedApp.binaryPath) {
      Quickshell.execDetached([installedApp.binaryPath])
    } else if (installedApp.desktopPath) {
      Util.execDetached("gtk-launch " + Util.shellQuote(installedApp.appId + ".desktop"))
    }
  }

  function openAppImageFolder() {
    var dir = root.installDirectory
    if (installedApp && installedApp.binaryPath) {
      var lastSlash = installedApp.binaryPath.lastIndexOf("/")
      if (lastSlash > 0) dir = installedApp.binaryPath.substring(0, lastSlash)
    }
    dir = dir.replace(/^~/, Quickshell.env("HOME"))
    Quickshell.execDetached(["xdg-open", dir])
  }

  Timer {
    id: progressTimer
    interval: 220
    repeat: true
    running: root.state === "installing"
    onTriggered: {
      if (root.progress < 0.45) {
        root.progress += 0.08
        root.currentStep = "Extracting metadata and original icons..."
      } else if (root.progress < 0.75) {
        root.progress += 0.06
        root.currentStep = "Deploying binary and generating launcher..."
      } else if (root.progress < 0.92) {
        root.progress += 0.03
        root.currentStep = "Updating Omarchy desktop database..."
      }
    }
  }

  Process {
    id: pickerProcess
    command: [
      "zenity",
      "--file-selection",
      "--title=Select .AppImage",
      "--file-filter=AppImage files (*.AppImage *.appimage) | *.AppImage *.appimage *.APPIMAGE",
      "--file-filter=All files | *"
    ]
    stdout: StdioCollector {
      id: pickerStdout
      waitForEnd: true
    }
    stderr: StdioCollector {
      id: pickerStderr
      waitForEnd: true
    }
    onExited: function(exitCode) {
      if (exitCode === 0) {
        var raw = String(pickerStdout.text || "").trim()
        if (raw.length > 0) {
          root.installApp(raw)
        } else {
          if (root.state === "selecting") root.state = "idle"
        }
      } else {
        if (root.state === "selecting") root.state = "idle"
      }
    }
  }

  Process {
    id: installProcess
    command: []
    stdout: StdioCollector {
      id: installStdout
      waitForEnd: true
    }
    stderr: StdioCollector {
      id: installStderr
      waitForEnd: true
    }
    onExited: function(exitCode) {
      progressTimer.stop()
      var outText = String(installStdout.text || "").trim()
      var errText = String(installStderr.text || "").trim()
      if (exitCode === 0) {
        try {
          var res = JSON.parse(outText)
          if (res && res.success) {
            root.installedApp = res
            root.progress = 1.0
            root.currentStep = "Installation complete!"
            root.state = "success"
            root.installFinished(res)
            return
          } else {
            root.state = "error"
            root.errorMessage = res && res.error ? res.error : (errText || "Installation reported failure.")
            root.installFailed(root.errorMessage)
            return
          }
        } catch (e) {
          root.state = "error"
          root.errorMessage = "Failed to parse installer output: " + e.message + "\n" + outText
          root.installFailed(root.errorMessage)
          return
        }
      } else {
        var msg = errText
        if (!msg) {
          try {
            var failObj = JSON.parse(outText)
            if (failObj && failObj.error) msg = failObj.error
          } catch (_) {}
        }
        if (!msg) msg = outText || "Process exited with error code " + exitCode
        root.state = "error"
        root.errorMessage = msg
        root.installFailed(root.errorMessage)
      }
    }
  }
}
