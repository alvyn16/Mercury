import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons as Commons
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "alvyn.mercurio"
  ipcTarget: "mercurio"
  manageIpc: true

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property color barForeground: bar ? bar.barForeground : Commons.Color.foreground

  InstallService {
    id: installService
    settings: root.settings
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    tooltipText: "Mercurio: AppImage Installer"
    iconComponent: Component {
      Item {
        PlanetIcon {
          anchors.centerIn: parent
          bar: root.bar
          iconSize: Style.space(16)
          planetColor: Commons.Color.accent
          ringColor: root.barForeground
          isBusy: installService.state === "installing"
        }
      }
    }
    onPressed: function (buttonCode) {
      root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: panel.loadedContent

    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight)

    content: PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      implicitHeight: installerCard.implicitHeight
      onCloseRequested: root.close()

      InstallerCard {
        id: installerCard
        width: parent.width
        service: installService
        panel: root
        onCloseRequested: root.close()
      }
    }
  }
}
