#!/bin/bash

set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

jq -e '
  .schemaVersion == 1
  and .id == "stappmus.dell-power-profiles"
  and (.kinds | index("bar-widget"))
  and .entryPoints.barWidget == "Panel.qml"
' "$root/manifest.json" >/dev/null

ROOT="$root" node <<'JS'
const path = require('path')
const model = require(path.join(process.env.ROOT, 'Model.js'))

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
  'plugin parses provider profiles and active state'
)
assertEqual(
  model.parseProfiles('__backend_missing__\n', 0).backendState,
  'missing',
  'plugin reports a missing backend'
)
assertEqual(
  model.parseProfiles('__provider_unavailable__\n', 0).backendState,
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
assertEqual(model.profileLabel('power-saver'), 'Power saver', 'plugin formats profile labels')
JS
