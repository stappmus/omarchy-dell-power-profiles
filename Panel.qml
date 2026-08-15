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
  // Own the IPC target so the percentage toggle can be exposed alongside the
  // standard panel controls.
  manageIpc: false

  property var batteryInfo: ({})
  property var profiles: []
  property string activeProfile: ""
  property string backendState: "checking"
  property var chargingProfiles: []
  property string activeChargingProfile: ""
  property string chargingBackendState: "checking"
  property string chargingCustomStart: ""
  property string chargingCustomStop: ""
  property string chargingCustomStartMin: ""
  property string chargingCustomStartMax: ""
  property string chargingCustomStartIncrement: ""
  property string chargingCustomStopMin: ""
  property string chargingCustomStopMax: ""
  property string chargingCustomStopIncrement: ""
  property bool chargingProfileBusy: false
  property string chargingProfileError: ""
  property string chargingAdjustmentNotice: ""
  property var pendingChargingArguments: []
  property int profileIndex: 0
  property bool cursorActive: false
  property bool restoredPowerSource: false
  property var pendingCommand: []

  readonly property bool backendReady: backendState === "ready"
  readonly property bool chargingBackendReady: chargingBackendState === "ready"
  readonly property var chargingProfileOptions: Model.chargingProfileOptions(
    chargingProfiles,
    chargingCustomStart,
    chargingCustomStop
  )
  readonly property string chargingProfileValue: activeChargingProfile ||
    (chargingBackendState === "checking" ? "Checking…" : "Unavailable")
  readonly property bool customChargingSelected: chargingProfileDropdown.value === "custom"
  readonly property bool customChargingControlsAvailable: Model.customChargingLimitsValid(
    chargingCustomStartMin,
    chargingCustomStartMax,
    chargingCustomStartIncrement,
    chargingCustomStopMin,
    chargingCustomStopMax,
    chargingCustomStopIncrement
  )
  readonly property string customChargingLimitsNotice: customChargingControlsAvailable
    ? Model.customChargingLimitsLabel(
        chargingCustomStartMin,
        chargingCustomStartMax,
        chargingCustomStopMin,
        chargingCustomStopMax
      )
    : ""
  readonly property bool showPercentage: setting("showPercentage", false) === true
  readonly property real openPanelIndicatorWidth: showPercentage && !button.vertical
    ? button.glyphPaintedWidth
    : 0
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
  readonly property string chargingProfileStatusDetail: {
    if (chargingProfileError !== "") return chargingProfileError
    if (chargingProfileBusy && chargeActionProc.requestedStart !== "")
      return "Applying " + Model.chargingProfileLabel(
        "custom",
        chargeActionProc.requestedStart,
        chargeActionProc.requestedStop
      ) + "…"
    if (chargingProfileBusy)
      return "Applying " + Model.chargingProfileLabel(
        chargeActionProc.requestedProfile,
        chargingCustomStart,
        chargingCustomStop
      ) + "…"
    if (chargingBackendState === "missing")
      return "Install or update the backend package to change Dell charging profiles."
    if (chargingBackendState === "unavailable")
      return "Dell charging controls are unavailable. Reinstall the backend or check the firmware interface."
    if (chargingBackendState === "checking") return "Checking Dell charging controls."
    if (chargingProfiles.length === 0) return "No compatible charging profiles are available."
    if (activeChargingProfile === "") return "The current charging profile could not be identified."
    if (customChargingSelected && !customChargingControlsAvailable)
      return "Dell did not expose editable custom charging percentages."
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
    refreshChargingProfiles()
    if (batteryPresent && !batteryProc.running) batteryProc.running = true
  }

  function refreshChargingProfiles() {
    if (!chargingProfilesProc.running) chargingProfilesProc.running = true
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

  function updateChargingProfiles(raw) {
    var parsed = Model.parseChargingProfiles(raw)
    chargingProfiles = parsed.profiles
    activeChargingProfile = parsed.activeProfile
    chargingBackendState = parsed.backendState
    chargingCustomStart = parsed.customStart
    chargingCustomStop = parsed.customStop
    chargingCustomStartMin = parsed.customStartMin
    chargingCustomStartMax = parsed.customStartMax
    chargingCustomStartIncrement = parsed.customStartIncrement
    chargingCustomStopMin = parsed.customStopMin
    chargingCustomStopMax = parsed.customStopMax
    chargingCustomStopIncrement = parsed.customStopIncrement
    chargingProfileDropdown.value = chargingProfileValue
    syncCustomChargingFields(false)
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

  function setChargingProfile(profile) {
    if (!chargingBackendReady || !profile || profile === activeChargingProfile) return
    chargingAdjustmentNotice = ""
    queueChargingAction([profile])
  }

  function setCustomChargingThreshold(start, stop) {
    if (!chargingBackendReady || !start || !stop) return
    if (start === chargingCustomStart && stop === chargingCustomStop) return
    queueChargingAction(["custom", String(start), String(stop)])
  }

  function syncCustomChargingFields(force) {
    if (force || !customStartField.activeFocus)
      customStartField.text = chargingCustomStart
    if (force || !customStopField.activeFocus)
      customStopField.text = chargingCustomStop
  }

  function applyCustomChargingField(editedField) {
    if (!chargingBackendReady || chargingProfileBusy || !customChargingControlsAvailable) {
      syncCustomChargingFields(true)
      return
    }

    var normalized = Model.normalizeCustomChargingThresholds(
      customStartField.text,
      customStopField.text,
      chargingCustomStart,
      chargingCustomStop,
      chargingCustomStartMin,
      chargingCustomStartMax,
      chargingCustomStartIncrement,
      chargingCustomStopMin,
      chargingCustomStopMax,
      chargingCustomStopIncrement,
      editedField
    )

    customStartField.text = normalized.start
    customStopField.text = normalized.stop
    chargingProfileError = ""
    chargingAdjustmentNotice = normalized.adjusted
      ? "Adjusted to " + normalized.start + "–" + normalized.stop + "% to fit the BIOS limits."
      : ""

    if (!normalized.valid) {
      chargingProfileError = "Dell custom charging limits are unavailable."
      return
    }
    setCustomChargingThreshold(normalized.start, normalized.stop)
  }

  function queueChargingAction(argumentsList) {
    pendingChargingArguments = argumentsList
    chargingProfileError = ""
    if (!chargeActionProc.running) runPendingChargingProfile()
  }

  function runPendingChargingProfile() {
    if (pendingChargingArguments.length === 0) return
    var argumentsList = pendingChargingArguments
    var command
    pendingChargingArguments = []
    chargeActionProc.requestedProfile = String(argumentsList[0] || "")
    chargeActionProc.requestedStart = String(argumentsList[1] || "")
    chargeActionProc.requestedStop = String(argumentsList[2] || "")
    command = [
      "/usr/bin/omarchy-dell-power-profiles",
      "charging",
      "set",
      chargeActionProc.requestedProfile
    ]
    if (chargeActionProc.requestedStart !== "") {
      command.push(chargeActionProc.requestedStart)
      command.push(chargeActionProc.requestedStop)
    }
    chargeActionProc.command = command
    chargingProfileBusy = true
    chargeActionProc.running = true
  }

  function togglePercentage() {
    root.settings = Object.assign({}, root.settings, { showPercentage: !root.showPercentage })
    if (root.bar && root.bar.shell)
      root.bar.shell.updateEntryInline(root.moduleName, root.settings)
  }

  IpcHandler {
    target: "stappmus.dell-power-profiles"

    function open() { root.open() }
    function close() { root.close() }
    function show() { root.open() }
    function hide() { root.close() }
    function toggle() { root.toggle() }
    function togglePercentage() { root.togglePercentage() }
  }

  onOpenedChanged: {
    if (!opened) {
      chargingProfileDropdown.close()
      customStartField.focus = false
      customStopField.focus = false
      return
    }
    if (!batteryPresent) {
      close()
      return
    }

    chargingAdjustmentNotice = ""
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
    id: chargingProfilesProc
    command: [
      "/usr/bin/bash",
      "-c",
      "if [[ ! -x /usr/bin/omarchy-dell-power-profiles ]] || ! /usr/bin/omarchy-dell-power-profiles --help 2>&1 | grep -q 'charging list'; then printf '__charging_backend_missing__\\n'; elif ! /usr/bin/omarchy-dell-power-profiles charging probe >/dev/null 2>&1; then printf '__charging_provider_unavailable__\\n'; else /usr/bin/omarchy-dell-power-profiles charging list --active-state 2>/dev/null; fi"
    ]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.updateChargingProfiles(text)
    }
  }

  Process {
    id: actionProc
    onExited: {
      root.refresh()
      root.runPendingAction()
    }
  }

  Process {
    id: chargeActionProc
    property string requestedProfile: ""
    property string requestedStart: ""
    property string requestedStop: ""
    property int lastExitCode: -1

    onRunningChanged: if (running) lastExitCode = -1
    stderr: StdioCollector {
      id: chargeActionStderr
      waitForEnd: true
      onStreamFinished: {
        var detail = String(text || "").trim()
        if (detail !== "" && chargeActionProc.lastExitCode > 0)
          root.chargingProfileError = detail
      }
    }
    onExited: function(exitCode) {
      lastExitCode = exitCode
      root.chargingProfileBusy = false
      if (exitCode === 0) {
        root.activeChargingProfile = requestedProfile
        if (requestedStart !== "") {
          root.chargingCustomStart = requestedStart
          root.chargingCustomStop = requestedStop
        }
        root.chargingProfileError = ""
      } else {
        var detail = String(chargeActionStderr.text || "").trim()
        root.chargingProfileError = detail || "Unable to change the Dell charging profile."
      }
      chargingProfileDropdown.value = root.activeChargingProfile
      root.syncCustomChargingFields(true)
      root.refreshChargingProfiles()
      root.runPendingChargingProfile()
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
    text: root.showPercentage && !vertical
      ? Math.round(root.batteryFraction * 100) + "% " + root.batteryIcon()
      : root.batteryIcon()
    slotSize: Style.bar.iconSlot * (root.showPercentage && !vertical ? 2 : 1)
    tooltipText: ""
    onPressed: function(b) {
      if (!root.batteryPresent) return
      if (b === Qt.RightButton) root.togglePercentage()
      else root.toggle()
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
      blocked: chargingProfileDropdown.popupOpen
        || customStartField.activeFocus
        || customStopField.activeFocus
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

        PanelSeparator {
          foreground: root.bar.foreground
        }

        Column {
          width: parent.width
          spacing: Style.space(10)

          PanelSectionHeader {
            text: "CHARGING PROFILE"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
          }

          Dropdown {
            id: chargingProfileDropdown
            width: parent.width
            showLabel: false
            value: root.chargingProfileValue
            options: root.chargingProfileOptions
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            enabled: root.chargingBackendReady
              && root.chargingProfiles.length > 0
              && !root.chargingProfileBusy
            opacity: enabled ? 1.0 : 0.6
            onChanged: function(next) { root.setChargingProfile(next) }
          }

          Row {
            visible: root.customChargingSelected && root.customChargingControlsAvailable
            width: parent.width
            spacing: Style.space(12)

            Column {
              width: (parent.width - parent.spacing) / 2
              spacing: Style.spacing.labelGap

              Text {
                text: "Start charging"
                color: Qt.darker(root.bar.foreground, 1.4)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }

              Row {
                width: parent.width
                spacing: Style.space(6)

                TextField {
                  id: customStartField
                  width: parent.width - startPercent.implicitWidth - parent.spacing
                  text: root.chargingCustomStart
                  placeholderText: root.chargingCustomStartMin
                  foreground: root.bar.foreground
                  font.family: root.bar.fontFamily
                  horizontalAlignment: TextInput.AlignRight
                  inputMethodHints: Qt.ImhDigitsOnly
                  maximumLength: 4
                  selectByMouse: true
                  enabled: root.chargingBackendReady
                    && root.activeChargingProfile === "custom"
                    && !root.chargingProfileBusy
                  opacity: enabled ? 1.0 : 0.6
                  onEditingFinished: root.applyCustomChargingField("start")
                  Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Escape) {
                      text = root.chargingCustomStart
                      focus = false
                      event.accepted = true
                    }
                  }
                }

                Text {
                  id: startPercent
                  anchors.verticalCenter: parent.verticalCenter
                  text: "%"
                  color: root.bar.foreground
                  opacity: 0.7
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.body
                }
              }
            }

            Column {
              width: (parent.width - parent.spacing) / 2
              spacing: Style.spacing.labelGap

              Text {
                text: "Stop charging"
                color: Qt.darker(root.bar.foreground, 1.4)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }

              Row {
                width: parent.width
                spacing: Style.space(6)

                TextField {
                  id: customStopField
                  width: parent.width - stopPercent.implicitWidth - parent.spacing
                  text: root.chargingCustomStop
                  placeholderText: root.chargingCustomStopMin
                  foreground: root.bar.foreground
                  font.family: root.bar.fontFamily
                  horizontalAlignment: TextInput.AlignRight
                  inputMethodHints: Qt.ImhDigitsOnly
                  maximumLength: 4
                  selectByMouse: true
                  enabled: root.chargingBackendReady
                    && root.activeChargingProfile === "custom"
                    && !root.chargingProfileBusy
                  opacity: enabled ? 1.0 : 0.6
                  onEditingFinished: root.applyCustomChargingField("stop")
                  Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Escape) {
                      text = root.chargingCustomStop
                      focus = false
                      event.accepted = true
                    }
                  }
                }

                Text {
                  id: stopPercent
                  anchors.verticalCenter: parent.verticalCenter
                  text: "%"
                  color: root.bar.foreground
                  opacity: 0.7
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.body
                }
              }
            }
          }

          Text {
            visible: root.customChargingSelected && root.customChargingControlsAvailable
            width: parent.width
            text: (root.chargingAdjustmentNotice !== ""
              ? root.chargingAdjustmentNotice + "\n"
              : "") + root.customChargingLimitsNotice
            color: root.bar.foreground
            opacity: 0.55
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }

          Text {
            visible: root.chargingProfileStatusDetail !== ""
            width: parent.width
            text: root.chargingProfileStatusDetail
            color: root.bar.foreground
            opacity: root.chargingProfileError !== "" ? 0.85 : 0.6
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
