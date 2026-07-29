function clampIndex(index, length) {
  if (length <= 0) return 0
  return Math.max(0, Math.min(length - 1, index))
}

function selectProfileIndex(index, delta, profiles) {
  var values = Array.isArray(profiles) ? profiles : []
  if (values.length === 0) return 0
  return clampIndex(index + delta, values.length)
}

function selectProfileIndexByDirection(index, dx, dy, profiles, columns) {
  var values = Array.isArray(profiles) ? profiles : []
  if (values.length === 0) return 0

  var current = clampIndex(index, values.length)
  var columnCount = Math.max(1, Math.min(values.length, columns || values.length))
  var rowCount = Math.ceil(values.length / columnCount)
  var direction
  var candidate

  if (rowCount === 1) {
    direction = dx !== 0 ? dx : dy
    return selectProfileIndex(current, Math.sign(direction), values)
  }

  if (dx !== 0) {
    candidate = current + Math.sign(dx)
    if (candidate < 0 || candidate >= values.length) return current
    if (Math.floor(candidate / columnCount) !== Math.floor(current / columnCount)) return current
    return candidate
  }

  if (dy !== 0) {
    candidate = current + Math.sign(dy) * columnCount
    return candidate >= 0 && candidate < values.length ? candidate : current
  }

  return current
}

function parseKeyValue(raw) {
  var values = {}
  var lines = String(raw || "").split("\n")

  for (var i = 0; i < lines.length; i++) {
    var separator = lines[i].indexOf("\t")
    if (separator <= 0) continue
    values[lines[i].substring(0, separator)] = lines[i].substring(separator + 1).trim()
  }

  return values
}

function parseProfiles(raw, previousIndex) {
  var lines = String(raw || "").split("\n")
  var profiles = []
  var activeProfile = ""
  var backendState = "ready"

  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trim()
    if (!line) continue

    if (line === "__backend_missing__") {
      backendState = "missing"
      continue
    }
    if (line === "__provider_unavailable__") {
      backendState = "unavailable"
      continue
    }

    var parts = line.split("\t")
    if (profiles.indexOf(parts[0]) < 0) profiles.push(parts[0])
    if (parts[1] === "1") activeProfile = parts[0]
  }

  return {
    profiles: profiles,
    activeProfile: activeProfile,
    backendState: backendState,
    profileIndex: clampIndex(previousIndex || 0, profiles.length)
  }
}

function profileIcon(name) {
  if (name === "quiet" || name === "power-saver") return "󰌪"
  if (name === "cool") return "󰼶"
  if (name === "balanced") return "󰊚"
  if (name === "performance") return "󰓅"
  return "󰂄"
}

function profileLabel(name) {
  var value = String(name || "").replace(/-/g, " ")
  return value ? value.charAt(0).toUpperCase() + value.slice(1) : ""
}

function batteryFraction(device) {
  return device && device.isPresent
    ? Math.max(0, Math.min(1, device.percentage))
    : 0
}

function chargeThresholdActive(device, onBattery, states) {
  var current = device || {}
  var values = states || {}
  if (!(current && current.isPresent && !onBattery)) return false

  var fraction = batteryFraction(current)
  if (current.state === values.Discharging) return false
  if (current.state === values.PendingCharge) return true
  if (current.state === values.FullyCharged && fraction < 0.99) return true
  if (current.state !== values.Charging || fraction >= 0.99) return false

  return Number(current.changeRate || 0) <= 0.2
    || Number(current.timeToFull || 0) >= 8 * 60 * 60
}

function batteryIcon(device, onBattery, states) {
  var current = device || {}
  if (!current.isPresent) return ""

  var chargingIcons = ["󰢜", "󰂆", "󰂇", "󰂈", "󰢝", "󰂉", "󰢞", "󰂊", "󰂋", "󰂅"]
  var defaultIcons = ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]
  var index = Math.max(0, Math.min(9, Math.floor(current.percentage * 10)))

  if (chargeThresholdActive(current, onBattery, states)) return defaultIcons[index]
  if (current.state === states.FullyCharged) return "󰂅"
  if (!onBattery) return chargingIcons[index]
  return defaultIcons[index]
}

function modeLabel(device, onBattery, states) {
  var current = device || {}
  if (!current.isPresent) return ""

  if (chargeThresholdActive(current, onBattery, states)) return "Threshold"
  if (onBattery) return "On battery"
  if (current.percentage >= 1) return "Fully charged"
  return "Charging"
}

if (typeof module !== "undefined") {
  module.exports = {
    clampIndex: clampIndex,
    selectProfileIndex: selectProfileIndex,
    selectProfileIndexByDirection: selectProfileIndexByDirection,
    parseKeyValue: parseKeyValue,
    parseProfiles: parseProfiles,
    profileIcon: profileIcon,
    profileLabel: profileLabel,
    batteryFraction: batteryFraction,
    chargeThresholdActive: chargeThresholdActive,
    batteryIcon: batteryIcon,
    modeLabel: modeLabel
  }
}
