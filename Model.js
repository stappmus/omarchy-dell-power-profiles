function clampIndex(index, length) {
  if (length <= 0) return 0
  return Math.max(0, Math.min(length - 1, index))
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
    return clampIndex(current + Math.sign(direction), values.length)
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
  if (name === "quiet") return "󰌪"
  if (name === "cool") return "󰼶"
  if (name === "balanced") return "󰊚"
  if (name === "performance") return "󰓅"
  return "󰂄"
}

function profileLabel(name) {
  var value = String(name || "").replace(/-/g, " ")
  return value ? value.charAt(0).toUpperCase() + value.slice(1) : ""
}

if (typeof module !== "undefined") {
  module.exports = {
    clampIndex: clampIndex,
    selectProfileIndexByDirection: selectProfileIndexByDirection,
    parseProfiles: parseProfiles,
    profileIcon: profileIcon,
    profileLabel: profileLabel
  }
}
