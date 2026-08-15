# Maintainer: Kristoffer Haugland <stappmus at gmail dot com>

pkgname=omarchy-dell-power-profiles
pkgver=1.2.0
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
  '99-omarchy-dell-platform-profile.rules'
  'omarchy-dell-power-profiles.install'
  'provider-test.sh'
  'README.md'
  'LICENSE'
)
sha256sums=(
  'ebc806f8538e5f367680c85421580cbede04a334aaa1d3192beba4c7e7b0f76b'
  '8c547c20d9a9c9f57a9bf4450b8526660af0d04fdcbbaf136ee0ef6494f1de01'
  'b347478cd46842a21a2b93c2736283959b6de6006c8bc3d31b6d6ccb86fc4a99'
  '7e94eb5cc9e3a7bf824b9bf1a8bdb8be92ac9cd6553c8e082754a03b31074c66'
  'e549d7624b36b76f09f30dc440a1184d5470457921d523cde48f79d788782e69'
  '3a91944679bc66990c9d99d93a5521e61bdc46f33d31050a78fb3c00ca41ce35'
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
