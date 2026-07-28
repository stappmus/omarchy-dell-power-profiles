# omarchy-dell-power-profiles

An optional Dell power-profile provider for Omarchy. It exposes the firmware
profiles `quiet`, `cool`, `balanced`, and `performance` through Omarchy's power
menu while keeping Dell-specific sysfs behavior outside Omarchy itself.

The provider coordinates each firmware mode with
[`power-profiles-daemon`](https://gitlab.freedesktop.org/upower/power-profiles-daemon):

| Dell firmware mode | OS power profile |
| --- | --- |
| `quiet` | `power-saver` |
| `cool` | `power-saver` |
| `balanced` | `balanced` |
| `performance` | `performance` |

Only modes supported by both the Dell firmware and
`power-profiles-daemon` are shown. A mode is marked active only when both
layers agree.

## Install

Build and install the Arch package:

```bash
makepkg --cleanbuild --install
```

The package installs:

- `/usr/lib/omarchy/powerprofiles.d/dell`, the provider used automatically by
  compatible Omarchy versions
- `/usr/bin/omarchy-dell-power-profiles`, a direct CLI symlink
- `/usr/lib/udev/rules.d/99-omarchy-dell-platform-profile.rules`, which grants
  the `wheel` group write access to the Dell firmware profile

The install hook reloads and reapplies the udev rule immediately. The
permissions are also recreated normally at boot, so no files under a user's
home directory are modified.

## CLI

```bash
omarchy-dell-power-profiles probe
omarchy-dell-power-profiles list
omarchy-dell-power-profiles list --active-state
omarchy-dell-power-profiles set autodetect quiet
omarchy-dell-power-profiles set ac performance
omarchy-dell-power-profiles set battery cool
```

Selections are remembered independently for AC and battery operation under
`$XDG_STATE_HOME/omarchy/powerprofiles`.

## Test

```bash
./provider-test.sh
makepkg --cleanbuild
```

The test suite uses temporary fake sysfs and `powerprofilesctl` implementations;
it does not change the host's power profile.
