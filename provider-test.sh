#!/bin/bash

set -euo pipefail

provider=${1:-./omarchy-dell-power-profiles}
provider=$(realpath "$provider")
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

fail() {
  echo "not ok - $1" >&2
  exit 1
}

pass() {
  echo "ok - $1"
}

profile_root="$test_root/platform-profile"
mkdir -p "$test_root/bin" "$test_root/state" "$profile_root/platform-profile-0" "$profile_root/platform-profile-1"

printf '%s\n' "SoC Power Slider" >"$profile_root/platform-profile-0/name"
printf '%s\n' "low-power balanced performance" >"$profile_root/platform-profile-0/choices"
printf '%s\n' "balanced" >"$profile_root/platform-profile-0/profile"
printf '%s\n' "dell-pc" >"$profile_root/platform-profile-1/name"
printf '%s\n' "cool quiet balanced performance" >"$profile_root/platform-profile-1/choices"
printf '%s\n' "quiet" >"$profile_root/platform-profile-1/profile"

cat >"$test_root/bin/powerprofilesctl" <<'EOF'
#!/bin/bash

case "$1" in
  list)
    for profile in performance balanced power-saver; do
      [[ $profile != "performance" || ${NO_PERFORMANCE:-0} == "0" ]] || continue
      if [[ $(<"$POWERPROFILES_OS_STATE") == "$profile" ]]; then
        printf '* %s:\n' "$profile"
      else
        printf '  %s:\n' "$profile"
      fi
    done
    ;;
  get)
    cat "$POWERPROFILES_OS_STATE"
    ;;
  set)
    printf '%s\n' "$2" >>"$POWERPROFILES_LOG"
    if [[ ${MAKE_FIRMWARE_READ_ONLY:-0} == "1" ]]; then
      chmod 444 "$DELL_PROFILE_FILE"
    fi
    if [[ ${POWERPROFILES_NEVER_SETTLE:-0} == "1" && $2 == "power-saver" ]]; then
      printf 'balanced\n' >"$POWERPROFILES_OS_STATE"
    elif [[ ${POWERPROFILES_STEP_DOWN:-0} == "1" && $(<"$POWERPROFILES_OS_STATE") == "performance" && $2 == "power-saver" ]]; then
      printf 'balanced\n' >"$POWERPROFILES_OS_STATE"
    else
      printf '%s\n' "$2" >"$POWERPROFILES_OS_STATE"
    fi
    ;;
esac
EOF
chmod +x "$test_root/bin/powerprofilesctl"

cat >"$test_root/bin/busctl" <<'EOF'
#!/bin/bash

if [[ ${ON_BATTERY:-0} == "1" ]]; then
  echo "b true"
else
  echo "b false"
fi
EOF
chmod +x "$test_root/bin/busctl"

export PATH="$test_root/bin:$PATH"
export POWERPROFILES_LOG="$test_root/calls"
export POWERPROFILES_OS_STATE="$test_root/os-profile"
export DELL_PROFILE_FILE="$profile_root/platform-profile-1/profile"
export OMARCHY_POWERPROFILES_STATE_DIR="$test_root/state"
export OMARCHY_PLATFORM_PROFILE_ROOT="$profile_root"
printf 'power-saver\n' >"$POWERPROFILES_OS_STATE"

"$provider" probe || fail "provider detects a usable Dell controller"
pass "provider detects a usable Dell controller"

output=$("$provider" list)
[[ $output == $'quiet\ncool\nbalanced\nperformance' ]] || fail "profiles use the intended order"
pass "profiles use the intended order"

output=$("$provider" list --active-state)
[[ $output == $'quiet\t1\ncool\t0\nbalanced\t0\nperformance\t0' ]] || fail "active state combines firmware and OS modes"
pass "active state combines firmware and OS modes"

printf 'balanced\n' >"$POWERPROFILES_OS_STATE"
output=$("$provider" list --active-state)
[[ $output == $'quiet\t0\ncool\t0\nbalanced\t0\nperformance\t0' ]] || fail "mismatched firmware and OS modes are inactive"
pass "mismatched firmware and OS modes are inactive"

output=$(NO_PERFORMANCE=1 "$provider" list)
[[ $output == $'quiet\ncool\nbalanced' ]] || fail "firmware modes require their mapped OS profile"
pass "firmware modes require their mapped OS profile"

printf 'power-saver\n' >"$test_root/state/battery"
ON_BATTERY=1 "$provider" set
[[ $(<"$POWERPROFILES_OS_STATE") == "power-saver" ]] || fail "saved OS power-saver keeps its mapped OS mode"
[[ $(<"$profile_root/platform-profile-1/profile") == "quiet" ]] || fail "saved OS power-saver migrates to Dell quiet"
pass "existing power-saver preferences migrate to Dell quiet"

for mapping in "quiet power-saver" "cool power-saver" "balanced balanced" "performance performance"; do
  read -r firmware_profile os_profile <<<"$mapping"
  previous_os_profile=$(<"$POWERPROFILES_OS_STATE")
  previous_call_count=$(wc -l <"$POWERPROFILES_LOG")
  "$provider" set ac "$firmware_profile"
  [[ $(tail -n 1 "$POWERPROFILES_LOG") == "$os_profile" ]] || fail "$firmware_profile selects OS $os_profile"
  [[ $(<"$POWERPROFILES_OS_STATE") == "$os_profile" ]] || fail "$firmware_profile updates the OS mode"
  [[ $(<"$profile_root/platform-profile-1/profile") == "$firmware_profile" ]] || fail "$firmware_profile updates Dell firmware"
  [[ $(<"$test_root/state/ac") == "$firmware_profile" ]] || fail "$firmware_profile is remembered"
  active_profile=$("$provider" list --active-state | awk '$2 == 1 { print $1 }')
  [[ $active_profile == "$firmware_profile" ]] || fail "$firmware_profile reports as active"
  if [[ $previous_os_profile == "$os_profile" ]]; then
    [[ $(wc -l <"$POWERPROFILES_LOG") == "$previous_call_count" ]] ||
      fail "$firmware_profile avoids a redundant OS profile write"
  fi
done
pass "all Dell profiles map, apply, persist, and avoid redundant OS writes"

if "$provider" set ac power-saver 2>/dev/null; then
  fail "hidden OS profiles cannot bypass the provider"
fi
pass "hidden OS profiles cannot bypass the provider"

if POWERPROFILES_NEVER_SETTLE=1 "$provider" set ac quiet 2>/dev/null; then
  fail "a profile that never settles is reported as failed"
fi
[[ $(<"$POWERPROFILES_OS_STATE") == "performance" ]] || fail "failed OS selection restores the previous OS mode"
[[ $(<"$profile_root/platform-profile-1/profile") == "performance" ]] || fail "failed OS selection leaves Dell firmware unchanged"
[[ $(<"$test_root/state/ac") == "performance" ]] || fail "failed OS selection preserves the preference"
pass "failed OS selection is rolled back"

call_count=$(wc -l <"$POWERPROFILES_LOG")
POWERPROFILES_STEP_DOWN=1 "$provider" set ac quiet
[[ $(wc -l <"$POWERPROFILES_LOG") == $(( call_count + 2 )) ]] || fail "stepped OS changes converge with bounded retries"
[[ $(<"$POWERPROFILES_OS_STATE") == "power-saver" ]] || fail "stepped OS change reaches power-saver"
[[ $(<"$profile_root/platform-profile-1/profile") == "quiet" ]] || fail "stepped OS change reaches Dell quiet"
pass "stepped OS changes converge with bounded retries"

if MAKE_FIRMWARE_READ_ONLY=1 "$provider" set ac performance 2>/dev/null; then
  fail "a failed firmware write is reported as failed"
fi
[[ $(<"$POWERPROFILES_OS_STATE") == "power-saver" ]] || fail "failed firmware write restores the previous OS mode"
[[ $(<"$profile_root/platform-profile-1/profile") == "quiet" ]] || fail "failed firmware write preserves the Dell mode"
[[ $(<"$test_root/state/ac") == "quiet" ]] || fail "failed firmware write preserves the preference"
pass "failed firmware writes roll back the OS mode"

chmod 444 "$profile_root/platform-profile-1/profile"
if "$provider" probe; then
  fail "provider ignores a controller that the user cannot change"
fi
pass "provider ignores a controller that the user cannot change"
