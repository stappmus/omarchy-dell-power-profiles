#!/bin/bash

set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

jq -e '
  .schemaVersion == 1
  and .id == "stappmus.dell-power-profiles"
  and (.kinds | index("bar-widget"))
  and .entryPoints.barWidget == "Panel.qml"
  and .barWidget.defaultSection == "right"
  and .barWidget.defaults.showPercentage == false
' "$root/manifest.json" >/dev/null

grep -F 'command: ["omarchy-battery-status", "--shell"]' "$root/Panel.qml" >/dev/null
grep -F '"/usr/bin/omarchy-dell-power-profiles", "set"' "$root/Panel.qml" >/dev/null
grep -F 'omarchy-powerprofiles-list --active-state' "$root/Panel.qml" >/dev/null
grep -F '"charging",' "$root/Panel.qml" >/dev/null
grep -F 'id: chargingProfileDropdown' "$root/Panel.qml" >/dev/null
grep -F 'id: customStartField' "$root/Panel.qml" >/dev/null
grep -F 'id: customStopField' "$root/Panel.qml" >/dev/null
grep -F 'BIOS limits:' "$root/Model.js" >/dev/null
grep -F 'blocked: chargingProfileDropdown.popupOpen' "$root/Panel.qml" >/dev/null
grep -F 'function togglePercentage()' "$root/Panel.qml" >/dev/null
grep -F 'if (b === Qt.RightButton) root.togglePercentage()' "$root/Panel.qml" >/dev/null
if grep -F 'omarchy-system-stats' "$root/Panel.qml" >/dev/null; then
  echo "not ok - plugin should not poll unused system statistics" >&2
  exit 1
fi

ROOT="$root" node <<'JS'
const path = require('path')
const model = require(path.join(process.env.ROOT, 'Model.js'))
const states = { Charging: 1, Discharging: 2, FullyCharged: 3, PendingCharge: 4 }

function assert(value, description) {
  if (!value) {
    console.error(`not ok - ${description}`)
    process.exit(1)
  }
  console.log(`ok - ${description}`)
}

function assertEqual(actual, expected, description) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    console.error(`not ok - ${description}`)
    console.error(`expected: ${JSON.stringify(expected)}`)
    console.error(`actual:   ${JSON.stringify(actual)}`)
    process.exit(1)
  }
  console.log(`ok - ${description}`)
}

assertEqual(
  model.parseProfiles('quiet\t1\ncool\t0\nbalanced\t0\nperformance\t0\n', 8),
  {
    profiles: ['quiet', 'cool', 'balanced', 'performance'],
    activeProfile: 'quiet',
    backendState: 'ready',
    profileIndex: 3
  },
  'plugin parses Dell profiles and active state'
)
assertEqual(
  model.parseProfiles('__backend_missing__\npower-saver\t1\nbalanced\t0\nperformance\t0\n', 0),
  {
    profiles: ['power-saver', 'balanced', 'performance'],
    activeProfile: 'power-saver',
    backendState: 'missing',
    profileIndex: 0
  },
  'plugin preserves standard profiles when the backend is missing'
)
assertEqual(
  model.parseProfiles('__provider_unavailable__\npower-saver\t0\nbalanced\t1\n', 0).backendState,
  'unavailable',
  'plugin reports unavailable Dell hardware'
)
assertEqual(
  model.selectProfileIndexByDirection(0, 0, 1, ['quiet', 'cool', 'balanced', 'performance'], 2),
  2,
  'plugin navigates between profile rows'
)
assertEqual(
  model.selectProfileIndexByDirection(1, 1, 0, ['quiet', 'cool', 'balanced', 'performance'], 2),
  1,
  'plugin does not wrap across profile rows'
)
assertEqual(
  model.selectProfileIndexByDirection(3, 0, 1, ['quiet', 'cool', 'balanced', 'performance'], 2),
  3,
  'plugin keeps grid navigation inside the profile list'
)
assertEqual(model.profileLabel('power-saver'), 'Power saver', 'plugin formats profile labels')
assert(model.profileIcon('quiet').length > 0, 'plugin maps Dell profile icons')

assertEqual(
  model.parseChargingProfiles(
    'adaptive\t1\nstandard\t0\nexpress\t0\nprimarily-ac\t0\ncustom\t0\t50\t90\t50\t95\t1\t55\t100\t1\n'
  ),
  {
    profiles: ['adaptive', 'standard', 'express', 'primarily-ac', 'custom'],
    activeProfile: 'adaptive',
    backendState: 'ready',
    customStart: '50',
    customStop: '90',
    customStartMin: '50',
    customStartMax: '95',
    customStartIncrement: '1',
    customStopMin: '55',
    customStopMax: '100',
    customStopIncrement: '1'
  },
  'plugin parses Dell charging profiles and the custom range'
)
assertEqual(
  model.parseChargingProfiles('__charging_backend_missing__\n').backendState,
  'missing',
  'plugin reports a missing charging-profile backend'
)
assertEqual(
  model.parseChargingProfiles('__charging_provider_unavailable__\n').backendState,
  'unavailable',
  'plugin reports unavailable Dell charging controls'
)
assertEqual(
  model.chargingProfileOptions(['adaptive', 'primarily-ac', 'custom'], '50', '80'),
  [
    { value: 'adaptive', label: 'Adaptive' },
    { value: 'primarily-ac', label: 'Primarily AC' },
    { value: 'custom', label: 'Custom · 50–80%' }
  ],
  'plugin formats charging profiles for the collapsed dropdown'
)
assert(
  model.customChargingLimitsValid('50', '95', '1', '55', '100', '1'),
  'plugin accepts the Dell custom charging metadata'
)
assertEqual(
  model.normalizeCustomChargingThresholds(
    '25%', '90', '50', '90', '50', '95', '1', '55', '100', '1', 'start'
  ),
  { start: '50', stop: '90', adjusted: true, valid: true },
  'custom start text clamps 25% to the BIOS minimum of 50%'
)
assertEqual(
  model.normalizeCustomChargingThresholds(
    '95', '90', '50', '90', '50', '95', '1', '55', '100', '1', 'start'
  ),
  { start: '95', stop: '100', adjusted: true, valid: true },
  'editing the start field raises stop to preserve the minimum gap'
)
assertEqual(
  model.normalizeCustomChargingThresholds(
    '90', '55', '90', '100', '50', '95', '1', '55', '100', '1', 'stop'
  ),
  { start: '50', stop: '55', adjusted: true, valid: true },
  'editing the stop field lowers start to preserve the minimum gap'
)
assertEqual(
  model.normalizeCustomChargingThresholds(
    '60', '80', '50', '90', '50', '95', '1', '55', '100', '1', 'start'
  ),
  { start: '60', stop: '80', adjusted: false, valid: true },
  'valid custom charging text remains unchanged'
)

assertEqual(
  model.parseKeyValue('time\t2:00\nenergy\t42\n'),
  { time: '2:00', energy: '42' },
  'power panel parses battery key-value output'
)
assertEqual(
  model.batteryFraction({ isPresent: true, percentage: 1.5 }),
  1,
  'power panel clamps battery fraction'
)
assert(
  model.chargeThresholdActive(
    { isPresent: true, percentage: 0.8, state: states.PendingCharge },
    false,
    states
  ),
  'power panel detects a pending charge threshold'
)
assert(
  !model.chargeThresholdActive(
    { isPresent: true, percentage: 0.8, state: states.Charging, changeRate: 1.0, timeToFull: 120 },
    false,
    states
  ),
  'power panel does not flag active charging as a threshold'
)
assertEqual(
  model.modeLabel(
    { isPresent: true, percentage: 1, state: states.FullyCharged },
    false,
    states
  ),
  'Fully charged',
  'power panel labels a full battery'
)
assertEqual(
  model.modeLabel(
    { isPresent: true, percentage: 0.5, state: states.Discharging },
    true,
    states
  ),
  'On battery',
  'power panel labels battery operation'
)
assert(
  model.batteryIcon(
    { isPresent: true, percentage: 0.4, state: states.Charging },
    false,
    states
  ).length > 0,
  'power panel maps battery icons'
)
JS
