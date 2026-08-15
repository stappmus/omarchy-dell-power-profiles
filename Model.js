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

function parseChargingProfiles(raw) {
  var lines = String(raw || "").split("\n")
  var profiles = []
  var activeProfile = ""
  var backendState = "ready"
  var customStart = ""
  var customStop = ""
  var customStartMin = ""
  var customStartMax = ""
  var customStartIncrement = ""
  var customStopMin = ""
  var customStopMax = ""
  var customStopIncrement = ""

  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trim()
    if (!line) continue

    if (line === "__charging_backend_missing__") {
      backendState = "missing"
      continue
    }
    if (line === "__charging_provider_unavailable__") {
      backendState = "unavailable"
      continue
    }

    var parts = line.split("\t")
    if (profiles.indexOf(parts[0]) < 0) profiles.push(parts[0])
    if (parts[1] === "1") activeProfile = parts[0]
    if (parts[0] === "custom") {
      customStart = String(parts[2] || "").trim()
      customStop = String(parts[3] || "").trim()
      customStartMin = String(parts[4] || "").trim()
      customStartMax = String(parts[5] || "").trim()
      customStartIncrement = String(parts[6] || "").trim()
      customStopMin = String(parts[7] || "").trim()
      customStopMax = String(parts[8] || "").trim()
      customStopIncrement = String(parts[9] || "").trim()
    }
  }

  return {
    profiles: profiles,
    activeProfile: activeProfile,
    backendState: backendState,
    customStart: customStart,
    customStop: customStop,
    customStartMin: customStartMin,
    customStartMax: customStartMax,
    customStartIncrement: customStartIncrement,
    customStopMin: customStopMin,
    customStopMax: customStopMax,
    customStopIncrement: customStopIncrement
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

function chargingProfileLabel(name, customStart, customStop) {
  if (name === "adaptive") return "Adaptive"
  if (name === "standard") return "Standard"
  if (name === "express") return "ExpressCharge"
  if (name === "primarily-ac") return "Primarily AC"
  if (name === "custom") {
    var start = String(customStart || "").trim()
    var stop = String(customStop || "").trim()
    return start && stop ? "Custom · " + start + "–" + stop + "%" : "Custom"
  }
  return profileLabel(name)
}

function chargingProfileOptions(profiles, customStart, customStop) {
  var values = Array.isArray(profiles) ? profiles : []
  var options = []

  for (var i = 0; i < values.length; i++) {
    options.push({
      value: values[i],
      label: chargingProfileLabel(values[i], customStart, customStop)
    })
  }

  return options
}

function percentageBounds(minimum, maximum, increment) {
  var low = Number(minimum)
  var high = Number(maximum)
  var step = Number(increment)

  if (!isFinite(low) || !isFinite(high) || !isFinite(step)
      || Math.floor(low) !== low || Math.floor(high) !== high
      || Math.floor(step) !== step || step <= 0 || low > high)
    return null

  return {
    minimum: low,
    maximum: low + Math.floor((high - low) / step) * step,
    increment: step
  }
}

function customChargingLimitsValid(startMinimum, startMaximum, startIncrement,
                                   stopMinimum, stopMaximum, stopIncrement) {
  var start = percentageBounds(startMinimum, startMaximum, startIncrement)
  var stop = percentageBounds(stopMinimum, stopMaximum, stopIncrement)
  return !!(start && stop && stop.maximum >= start.minimum + 5)
}

function percentageInput(raw, fallback) {
  var match = String(raw || "").trim().match(/^([+-]?\d+)\s*%?$/)
  var value = match ? Number(match[1]) : Number(fallback)
  return {
    value: isFinite(value) ? value : 0,
    valid: !!match && isFinite(value)
  }
}

function snapPercentage(value, bounds) {
  var clamped = Math.max(bounds.minimum, Math.min(bounds.maximum, value))
  var steps = Math.round((clamped - bounds.minimum) / bounds.increment)
  return Math.max(
    bounds.minimum,
    Math.min(bounds.maximum, bounds.minimum + steps * bounds.increment)
  )
}

function normalizeCustomChargingThresholds(startRaw, stopRaw, currentStart, currentStop,
                                           startMinimum, startMaximum, startIncrement,
                                           stopMinimum, stopMaximum, stopIncrement,
                                           editedField) {
  var startBounds = percentageBounds(startMinimum, startMaximum, startIncrement)
  var stopBounds = percentageBounds(stopMinimum, stopMaximum, stopIncrement)
  var startInput = percentageInput(startRaw, currentStart)
  var stopInput = percentageInput(stopRaw, currentStop)

  if (!startBounds || !stopBounds || stopBounds.maximum < startBounds.minimum + 5) {
    return {
      start: String(currentStart || ""),
      stop: String(currentStop || ""),
      adjusted: true,
      valid: false
    }
  }

  var start = snapPercentage(startInput.value, startBounds)
  var stop = snapPercentage(stopInput.value, stopBounds)

  if (editedField === "stop") {
    while (start > stop - 5 && start - startBounds.increment >= startBounds.minimum)
      start -= startBounds.increment
    while (stop < start + 5 && stop + stopBounds.increment <= stopBounds.maximum)
      stop += stopBounds.increment
  } else {
    while (stop < start + 5 && stop + stopBounds.increment <= stopBounds.maximum)
      stop += stopBounds.increment
    while (start > stop - 5 && start - startBounds.increment >= startBounds.minimum)
      start -= startBounds.increment
  }

  return {
    start: String(start),
    stop: String(stop),
    adjusted: !startInput.valid || !stopInput.valid
      || startInput.value !== start || stopInput.value !== stop,
    valid: stop >= start + 5
  }
}

function customChargingLimitsLabel(startMinimum, startMaximum, stopMinimum, stopMaximum) {
  return "BIOS limits: start " + startMinimum + "–" + startMaximum
    + "%, stop " + stopMinimum + "–" + stopMaximum
    + "% · minimum 5% gap. Out-of-range values are adjusted."
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
    parseChargingProfiles: parseChargingProfiles,
    profileIcon: profileIcon,
    profileLabel: profileLabel,
    chargingProfileLabel: chargingProfileLabel,
    chargingProfileOptions: chargingProfileOptions,
    customChargingLimitsValid: customChargingLimitsValid,
    normalizeCustomChargingThresholds: normalizeCustomChargingThresholds,
    customChargingLimitsLabel: customChargingLimitsLabel,
    batteryFraction: batteryFraction,
    chargeThresholdActive: chargeThresholdActive,
    batteryIcon: batteryIcon,
    modeLabel: modeLabel
  }
}
