# Maintainer: Kristoffer Haugland <stappmus at gmail dot com>

pkgname=omarchy-dell-power-profiles
pkgver=1.2.2
pkgrel=1
pkgdesc="Dell firmware power and charging-profile backend for Omarchy"
arch=('any')
url="https://github.com/stappmus/omarchy-dell-power-profiles"
license=('MIT')
depends=('bash' 'power-profiles-daemon' 'systemd')
install=omarchy-dell-power-profiles.install
options=('!debug')
source=(
  'omarchy-dell-power-profiles'
  'omarchy-dell-power-profiles-permissions'
  'omarchy-dell-power-profiles-permissions.service'
  '99-omarchy-dell-platform-profile.rules'
  'omarchy-dell-power-profiles.install'
  'provider-test.sh'
  'README.md'
  'LICENSE'
)
sha256sums=(
  '5b7640e85bebceb2ade4fb380b7fdadaeb8e04c1e5a7a506d62f37cf8ce9a9ce'
  'a88f514285dca91714ed913213180e07f31901489559f681c96cfa1b2b251cd2'
  'ff888b2e65b22de97ea909cf2f4399ac33f442b6b7a103df389733804eb79212'
  'c43b778c72f39feb5bf9e28606a8bd705fe83d1531b45dbb63278b532a10814a'
  '96a26d55e35855c53ebb844bcfb80f39a0d14b180e37536257de063ee9804a0f'
  'be8b559337efc9ae6676a602252d93770f51a4f1416ec76fee89c026b6c4ba6b'
  '2ea041a63217509ce738a0c7c65b9b2ea14022c6a6199569c3210712aaa1526a'
  '3a91944679bc66990c9d99d93a5521e61bdc46f33d31050a78fb3c00ca41ce35'
)

check() {
  bash provider-test.sh \
    ./omarchy-dell-power-profiles \
    ./omarchy-dell-power-profiles-permissions
}

package() {
  install -Dm755 omarchy-dell-power-profiles \
    "$pkgdir/usr/lib/omarchy/powerprofiles.d/dell"
  install -d "$pkgdir/usr/bin"
  ln -s ../lib/omarchy/powerprofiles.d/dell \
    "$pkgdir/usr/bin/omarchy-dell-power-profiles"
  install -Dm755 omarchy-dell-power-profiles-permissions \
    "$pkgdir/usr/lib/omarchy/dell-power-profiles/apply-charging-permissions"
  install -Dm644 omarchy-dell-power-profiles-permissions.service \
    "$pkgdir/usr/lib/systemd/system/omarchy-dell-power-profiles-permissions.service"
  install -Dm644 99-omarchy-dell-platform-profile.rules \
    "$pkgdir/usr/lib/udev/rules.d/99-omarchy-dell-platform-profile.rules"
  install -Dm644 README.md \
    "$pkgdir/usr/share/doc/$pkgname/README.md"
  install -Dm644 LICENSE \
    "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
}
