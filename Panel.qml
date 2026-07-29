import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Drop-in replacement for Omarchy's power widget. The battery UI stays
// familiar while the profile section coordinates Dell firmware and PPD.
Panel {
  id: root
  moduleName: "stappmus.dell-power-profiles"
  ipcTarget: "stappmus.dell-power-profiles"

  property var batteryInfo: ({})
  property var profiles: []
  property string activeProfile: ""
  property string backendState: "checking"
  property int profileIndex: 0
  property bool cursorActive: false
  property bool restoredPowerSource: false
  property var pendingCommand: []

  readonly property bool backendReady: backendState === "ready"
  readonly property int profileColumns: profiles.length > 3 ? 2 : Math.max(1, profiles.length)
  readonly property bool batteryPresent: {
    var device = UPower.displayDevice
    return !!(device && device.isPresent)
  }
  readonly property string profileSectionTitle: backendReady ? "DELL POWER PROFILE" : "POWER PROFILE"
  readonly property string profileStatusDetail: {
    if (backendState === "missing")
      return "Install the backend package to add Dell quiet and cool modes. Standard OS profiles remain available."
    if (backendState === "unavailable")
      return "The Dell controller is unavailable. Standard OS profiles remain available."
    if (backendState === "checking") return "Checking the Dell power-profile backend."
    if (profiles.length === 0) return "No compatible power profiles are available."
    return ""
  }

  function upowerStates() {
    return {
      Charging: UPowerDeviceState.Charging,
      Discharging: UPowerDeviceState.Discharging,
      FullyCharged: UPowerDeviceState.FullyCharged,
      PendingCharge: UPowerDeviceState.PendingCharge
    }
  }

  function powerSource() {
    return UPower.onBattery ? "battery" : "ac"
  }

  function selectProfileByDirection(dx, dy) {
    profileIndex = Model.selectProfileIndexByDirection(profileIndex, dx, dy, profiles, profileColumns)
  }

  function activateSelectedProfile() {
    if (profileIndex < 0 || profileIndex >= profiles.length) return
    setProfile(profiles[profileIndex])
  }

  function batteryIcon() {
    return Model.batteryIcon(UPower.displayDevice, root.discharging, upowerStates())
  }

  function modeLabel() {
    return Model.modeLabel(UPower.displayDevice, root.discharging, upowerStates())
  }

  readonly property bool fullyCharged: {
    var device = UPower.displayDevice
    return device && device.isPresent
      && device.state === UPowerDeviceState.FullyCharged
      && !root.chargeThresholdActive
  }
  readonly property bool discharging: {
    var device = UPower.displayDevice
    return !!(device && device.isPresent && UPower.onBattery)
  }
  readonly property bool chargeThresholdActive: {
    return Model.chargeThresholdActive(UPower.displayDevice, root.discharging, upowerStates())
  }
  readonly property bool batteryFull: fullyCharged || (!root.discharging && batteryFraction >= 1)
  readonly property bool batteryFlowIdle: batteryFull || chargeThresholdActive
  readonly property real batteryFraction: Model.batteryFraction(UPower.displayDevice)
  readonly property bool charging: {
    var device = UPower.displayDevice
    return device && device.isPresent && !UPower.onBattery && !root.batteryFlowIdle
  }
  readonly property color batteryFillColor: root.bar ? root.bar.foreground : Color.foreground

  readonly property var chargingPhrases: [
    "Pumping power",
    "Injecting electrons",
    "Pouring juice",
    "Amassing watts",
    "Hoarding joules",
    "Sucking volts",
    "Topping reserves",
    "Soaking amps",
    "Inhaling kilowatts"
  ]
  readonly property var onBatteryPhrases: [
    "Slurping power",
    "Spending joules",
    "Draining watts",
    "Burning electrons",
    "Sipping juice",
    "Spending coulombs",
    "Bleeding amps",
    "Guzzling volts",
    "Munching reserves"
  ]
  property int phraseIndex: 0

  readonly property var activePhrases: {
    if (fullyCharged) return []
    if (charging) return chargingPhrases
    if (discharging) return onBatteryPhrases
    return []
  }
  readonly property bool rotatingPhrases: activePhrases.length > 0
  readonly property string heroStatusText: {
    if (fullyCharged) return "Fully charged"
    if (rotatingPhrases) return activePhrases[phraseIndex % activePhrases.length]
    return modeLabel()
  }

  function refresh() {
    if (!profilesProc.running) profilesProc.running = true
    if (batteryPresent && !batteryProc.running) batteryProc.running = true
  }

  function updateBattery(raw) {
    var next = Model.parseKeyValue(raw)
    if (Object.keys(next).length > 0) batteryInfo = next
  }

  function updateProfiles(raw) {
    var parsed = Model.parseProfiles(raw, profileIndex)
    backendState = parsed.backendState

    if (parsed.profiles.length === 0) {
      profiles = []
      activeProfile = ""
      if (parsed.backendState !== "ready") restoredPowerSource = false
      return
    }

    profiles = parsed.profiles
    activeProfile = parsed.activeProfile
    profileIndex = parsed.profileIndex

    if (opened && !cursorActive) {
      var index = profiles.indexOf(activeProfile)
      if (index >= 0) profileIndex = index
    }

    if (parsed.backendState !== "ready") {
      restoredPowerSource = false
      return
    }

    if (!restoredPowerSource) {
      restoredPowerSource = true
      queueAction(["/usr/bin/omarchy-dell-power-profiles", "set", powerSource()])
    }
  }

  function queueAction(command) {
    pendingCommand = command
    if (!actionProc.running) runPendingAction()
  }

  function runPendingAction() {
    if (pendingCommand.length === 0) return
    actionProc.command = pendingCommand
    pendingCommand = []
    actionProc.running = true
  }

  function setProfile(profile) {
    if (!profile) return
    if (backendReady) {
      queueAction(["/usr/bin/omarchy-dell-power-profiles", "set", powerSource(), profile])
    } else {
      queueAction(["omarchy-powerprofiles-set", powerSource(), profile])
    }
  }

  onOpenedChanged: {
    if (!opened) return
    if (!batteryPresent) {
      close()
      return
    }

    refresh()
    var index = profiles.indexOf(activeProfile)
    profileIndex = index >= 0 ? index : 0
    cursorActive = false
  }

  onBatteryPresentChanged: if (!batteryPresent) close()
  Component.onCompleted: if (!profilesProc.running) profilesProc.running = true

  Connections {
    target: UPower
    function onOnBatteryChanged() {
      if (root.backendReady)
        root.queueAction(["/usr/bin/omarchy-dell-power-profiles", "set", root.powerSource()])
    }
  }

  visible: batteryPresent
  implicitWidth: batteryPresent ? button.implicitWidth : 0
  implicitHeight: batteryPresent ? button.implicitHeight : 0

  Process {
    id: batteryProc
    command: ["omarchy-battery-status", "--shell"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.updateBattery(text)
    }
  }

  Process {
    id: profilesProc
    command: [
      "/usr/bin/bash",
      "-c",
      "if [[ ! -x /usr/bin/omarchy-dell-power-profiles ]]; then printf '__backend_missing__\\n'; omarchy-powerprofiles-list --active-state 2>/dev/null || true; elif ! /usr/bin/omarchy-dell-power-profiles probe >/dev/null 2>&1; then printf '__provider_unavailable__\\n'; omarchy-powerprofiles-list --active-state 2>/dev/null || true; else /usr/bin/omarchy-dell-power-profiles list --active-state 2>/dev/null; fi"
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
      root.runPendingAction()
    }
  }

  Timer {
    interval: 5000
    running: root.opened
    repeat: true
    onTriggered: root.refresh()
  }

  Timer {
    id: phraseTimer
    interval: 2800
    running: root.opened && root.rotatingPhrases
    repeat: true
    triggeredOnStart: false
    onTriggered: phraseSwap.restart()
  }

  SequentialAnimation {
    id: phraseSwap
    PropertyAnimation {
      target: heroStatus
      property: "opacity"
      to: 0.0
      duration: 180
      easing.type: Easing.OutQuad
    }
    ScriptAction {
      script: {
        var count = root.activePhrases.length
        if (count > 0) root.phraseIndex = (root.phraseIndex + 1) % count
      }
    }
    PropertyAnimation {
      target: heroStatus
      property: "opacity"
      to: 1.0
      duration: 260
      easing.type: Easing.InQuad
    }
  }

  Connections {
    target: root
    function onRotatingPhrasesChanged() {
      if (!root.rotatingPhrases) {
        phraseSwap.stop()
        heroStatus.opacity = 1.0
      }
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.batteryIcon()
    tooltipText: ""
    onPressed: function(b) {
      if (root.batteryPresent) root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened && root.batteryPresent
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
      onTabRequested: function(direction) {
        root.switchPanel(direction)
      }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(14)

        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, heroPercent.implicitHeight)

          Text {
            id: heroIcon
            text: root.batteryIcon()
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.display
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color {
              ColorAnimation {
                duration: 200
              }
            }
          }

          Column {
            id: heroLabels
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(14)
            anchors.right: heroPercent.left
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              width: parent.width
              text: "Battery"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
            }

            Text {
              id: heroStatus
              width: parent.width
              text: root.heroStatusText.toUpperCase()
              color: Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
              elide: Text.ElideRight
            }
          }

          Text {
            id: heroPercent
            text: root.batteryInfo.percentage || "—"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.displayLarge
            font.bold: true
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color {
              ColorAnimation {
                duration: 200
              }
            }
          }
        }

        Item {
          width: parent.width
          implicitHeight: Style.space(8)

          Rectangle {
            id: barTrack
            anchors.fill: parent
            radius: height / 2
            color: Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.12)
          }

          Rectangle {
            id: barFill
            anchors.left: barTrack.left
            anchors.verticalCenter: barTrack.verticalCenter
            height: barTrack.height
            radius: barTrack.radius
            color: root.batteryFillColor
            width: Math.max(barTrack.height, barTrack.width * root.batteryFraction)

            Behavior on width {
              NumberAnimation {
                duration: 320
                easing.type: Easing.OutCubic
              }
            }
            Behavior on color {
              ColorAnimation {
                duration: 220
              }
            }

            SequentialAnimation on opacity {
              running: root.charging && !root.fullyCharged && root.opened
              loops: Animation.Infinite
              alwaysRunToEnd: true
              NumberAnimation {
                from: 1.0
                to: 0.55
                duration: 950
                easing.type: Easing.InOutSine
              }
              NumberAnimation {
                from: 0.55
                to: 1.0
                duration: 950
                easing.type: Easing.InOutSine
              }
            }
          }
        }

        Row {
          visible: root.batteryInfo.percentage !== undefined
          width: parent.width
          spacing: Style.space(20)

          Column {
            width: (parent.width - parent.spacing) / 2
            spacing: Style.spacing.labelGap
            InfoPair {
              label: "Battery size"
              value: root.batteryInfo.size || ""
            }
            InfoPair {
              label: "Charge cycles"
              value: root.batteryInfo.cycles || "—"
            }
          }

          Column {
            width: (parent.width - parent.spacing) / 2
            spacing: Style.spacing.labelGap
            InfoPair {
              label: root.chargeThresholdActive
                ? "Charge limit"
                : (root.discharging ? "Time left" : "Time to full")
              value: root.chargeThresholdActive
                ? (root.batteryInfo.threshold || "-")
                : (root.batteryFlowIdle ? "-" : (root.batteryInfo.time || "—"))
            }
            InfoPair {
              label: root.chargeThresholdActive
                ? "Battery state"
                : (root.discharging ? "Discharging" : "Charging")
              value: root.chargeThresholdActive
                ? "Holding"
                : (root.batteryFull ? "-" : (root.batteryInfo.rate || ""))
            }
          }
        }

        PanelSeparator {
          foreground: root.bar.foreground
        }

        Column {
          width: parent.width
          spacing: Style.space(10)

          PanelSectionHeader {
            text: root.profileSectionTitle
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
          }

          Grid {
            id: profileGrid
            visible: root.profiles.length > 0
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
            visible: root.profileStatusDetail !== ""
            width: parent.width
            text: root.profileStatusDetail
            color: root.bar.foreground
            opacity: 0.6
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }
        }
      }
    }
  }

  component InfoPair: Row {
    property string label: ""
    property string value: ""

    width: parent.width
    spacing: Style.space(8)

    InfoLabel {
      text: label
    }
    Item {
      width: Math.max(
        0,
        parent.width
          - parent.children[0].implicitWidth
          - parent.children[2].implicitWidth
          - parent.spacing * 2
      )
      height: 1
    }
    InfoValue {
      text: value
    }
  }

  component InfoLabel: Text {
    color: root.bar.foreground
    opacity: 0.6
    font.family: root.bar.fontFamily
    font.pixelSize: Style.font.bodySmall
  }

  component InfoValue: Text {
    color: root.bar.foreground
    font.family: root.bar.fontFamily
    font.pixelSize: Style.font.bodySmall
  }
}
