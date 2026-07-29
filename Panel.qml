import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "stappmus.dell-power-profiles"
  ipcTarget: "stappmus.dell-power-profiles"

  property var profiles: []
  property string activeProfile: ""
  property string backendState: "checking"
  property int profileIndex: 0
  property bool cursorActive: false
  property bool restoredPowerSource: false
  property var pendingSetArgs: []

  readonly property int profileColumns: profiles.length > 3 ? 2 : Math.max(1, profiles.length)
  readonly property bool backendReady: backendState === "ready"
  readonly property string statusTitle: {
    if (backendState === "missing") return "Backend not installed"
    if (backendState === "unavailable") return "Dell controller unavailable"
    if (backendState === "checking") return "Checking hardware"
    if (profiles.length === 0) return "No profiles available"
    return activeProfile ? Model.profileLabel(activeProfile) : "Synchronizing profiles"
  }
  readonly property string statusDetail: {
    if (backendState === "missing") return "Install the omarchy-dell-power-profiles package from the plugin repository."
    if (backendState === "unavailable") return "A writable dell-pc platform-profile controller and power-profiles-daemon are required."
    if (backendState === "checking") return "Looking for the packaged Dell power-profile provider."
    if (profiles.length === 0) return "No firmware mode has a matching OS power profile."
    return "Dell firmware and the OS power profile are coordinated."
  }

  function refresh() {
    if (!profilesProc.running) profilesProc.running = true
  }

  function updateProfiles(raw) {
    var parsed = Model.parseProfiles(raw, profileIndex)
    backendState = parsed.backendState

    if (!backendReady) {
      profiles = []
      activeProfile = ""
      restoredPowerSource = false
      return
    }

    profiles = parsed.profiles
    activeProfile = parsed.activeProfile
    profileIndex = parsed.profileIndex

    if (opened && !cursorActive) {
      var index = profiles.indexOf(activeProfile)
      if (index >= 0) profileIndex = index
    }

    if (!restoredPowerSource && profiles.length > 0) {
      restoredPowerSource = true
      queueSet([UPower.onBattery ? "battery" : "ac"])
    }
  }

  function selectProfileByDirection(dx, dy) {
    profileIndex = Model.selectProfileIndexByDirection(profileIndex, dx, dy, profiles, profileColumns)
  }

  function activateSelectedProfile() {
    if (profileIndex < 0 || profileIndex >= profiles.length) return
    setProfile(profiles[profileIndex])
  }

  function setProfile(profile) {
    if (!backendReady || !profile) return
    queueSet(["autodetect", profile])
  }

  function queueSet(args) {
    pendingSetArgs = args
    if (!actionProc.running) runPendingSet()
  }

  function runPendingSet() {
    if (pendingSetArgs.length === 0) return
    var args = pendingSetArgs
    pendingSetArgs = []
    actionProc.command = ["omarchy-dell-power-profiles", "set"].concat(args)
    actionProc.running = true
  }

  onOpenedChanged: {
    if (!opened) return
    refresh()
    var index = profiles.indexOf(activeProfile)
    profileIndex = index >= 0 ? index : 0
    cursorActive = false
  }

  Component.onCompleted: refresh()

  Connections {
    target: UPower
    function onOnBatteryChanged() {
      if (root.backendReady) root.queueSet([UPower.onBattery ? "battery" : "ac"])
    }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Process {
    id: profilesProc
    command: [
      "bash",
      "-lc",
      "if ! command -v omarchy-dell-power-profiles >/dev/null 2>&1; then printf '__backend_missing__\\n'; elif ! omarchy-dell-power-profiles probe >/dev/null 2>&1; then printf '__provider_unavailable__\\n'; else output=$(omarchy-dell-power-profiles list --active-state 2>/dev/null); if [[ -n $output ]]; then printf '%s\\n' \"$output\"; else printf '__provider_unavailable__\\n'; fi; fi"
    ]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.updateProfiles(text)
    }
  }

  Process {
    id: actionProc
    onExited: {
      root.refresh()
      root.runPendingSet()
    }
  }

  Timer {
    interval: 5000
    running: root.opened
    repeat: true
    onTriggered: root.refresh()
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.activeProfile ? Model.profileIcon(root.activeProfile) : "󰠠"
    fixedWidth: root.bar && root.bar.vertical ? -1 : Style.space(27)
    fixedHeight: root.bar && root.bar.vertical ? Style.space(26) : -1
    tooltipText: "Dell power: " + root.statusTitle
    onPressed: function(b) { root.toggle() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) {
          root.cursorActive = true
          return
        }
        root.selectProfileByDirection(dx, dy)
      }
      onActivateRequested: if (root.cursorActive) root.activateSelectedProfile()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(14)

        Row {
          width: parent.width
          spacing: Style.space(12)

          Text {
            text: root.activeProfile ? Model.profileIcon(root.activeProfile) : "󰠠"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.display
            anchors.verticalCenter: parent.verticalCenter
          }

          Column {
            width: parent.width - parent.children[0].implicitWidth - parent.spacing
            spacing: Style.space(2)

            Text {
              width: parent.width
              text: "Dell Power Profiles"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
            }

            Text {
              width: parent.width
              text: root.statusTitle.toUpperCase()
              color: Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.1
              elide: Text.ElideRight
            }
          }
        }

        PanelSeparator {
          foreground: root.bar.foreground
        }

        Text {
          visible: !root.backendReady || root.profiles.length === 0
          width: parent.width
          text: root.statusDetail
          color: root.bar.foreground
          opacity: 0.7
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        Grid {
          id: profileGrid
          visible: root.backendReady && root.profiles.length > 0
          width: parent.width
          columns: root.profileColumns
          columnSpacing: Style.space(6)
          rowSpacing: Style.space(6)

          readonly property real cellWidth: root.profiles.length > 0
            ? (width - columnSpacing * (columns - 1)) / columns
            : 0

          Repeater {
            model: root.profiles

            Button {
              required property var modelData
              required property int index
              width: profileGrid.cellWidth
              iconText: Model.profileIcon(String(modelData))
              iconSize: Style.font.title
              text: Model.profileLabel(String(modelData))
              fontSize: Style.font.bodySmall
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              horizontalPadding: Style.spacing.controlPaddingX
              verticalPadding: Style.spacing.controlPaddingY + Style.space(2)
              bordered: true
              active: root.activeProfile === modelData
              hasCursor: root.cursorActive && root.profileIndex === index
              onClicked: root.setProfile(modelData)
              onHovered: function(hovered) {
                if (!hovered) return
                root.cursorActive = true
                root.profileIndex = index
              }
            }
          }
        }

        Text {
          visible: root.backendReady && root.profiles.length > 0
          width: parent.width
          text: root.statusDetail
          color: root.bar.foreground
          opacity: 0.55
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }
      }
    }
  }
}
