# Maintainer: Kristoffer Haugland <stappmus at gmail dot com>

pkgname=omarchy-dell-power-profiles
pkgver=1.0.0
pkgrel=1
pkgdesc="Dell firmware power-profile provider for Omarchy"
arch=('any')
url="https://github.com/basecamp/omarchy/pull/6346"
license=('MIT')
depends=('bash' 'power-profiles-daemon' 'systemd')
install=omarchy-dell-power-profiles.install
options=('!debug')
source=(
  'omarchy-dell-power-profiles'
  '99-omarchy-dell-platform-profile.rules'
  'omarchy-dell-power-profiles.install'
  'provider-test.sh'
  'README.md'
  'LICENSE'
)
sha256sums=(
  '691be6a79e823074573baa52fbef71174986c52e38482c1cc1160ab1e9ca414e'
  'f3e910a2da1c0dd0318575cf37f1418eabd3deb8a5da5b83618f19ecaf912ad1'
  'd1e779da734452ea17ca221abeac5c4425c5fda79e05f384af4ca0da401eae49'
  '35129170ec70c398edcd04f70164aa9247cb19d065ec2a79010e0d1d853efa32'
  'cc914a7c1d9c12c8194b11e741f8c6e6cd95d1cf9f7f007bc03379c12248a8a6'
  'e728f356916d5e91693e02eb9e7e1f79289c2ca61e59bd35a45da10ee02fa3b3'
)

check() {
  bash provider-test.sh ./omarchy-dell-power-profiles
}

package() {
  install -Dm755 omarchy-dell-power-profiles \
    "$pkgdir/usr/lib/omarchy/powerprofiles.d/dell"
  install -d "$pkgdir/usr/bin"
  ln -s ../lib/omarchy/powerprofiles.d/dell \
    "$pkgdir/usr/bin/omarchy-dell-power-profiles"
  install -Dm644 99-omarchy-dell-platform-profile.rules \
    "$pkgdir/usr/lib/udev/rules.d/99-omarchy-dell-platform-profile.rules"
  install -Dm644 README.md \
    "$pkgdir/usr/share/doc/$pkgname/README.md"
  install -Dm644 LICENSE \
    "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
}
