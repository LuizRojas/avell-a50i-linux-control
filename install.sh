#!/bin/sh
# Instala o Avell Control Center para Linux (driver DKMS + app).
set -eu
[ "$(id -u)" -eq 0 ] || exec sudo "$0" "$@"
cd "$(dirname "$0")"

VER=1.0.0
SRC=/usr/src/avell-dchu-$VER

echo ">> Dependências"
if command -v apt-get >/dev/null; then
    apt-get install -y dkms "linux-headers-$(uname -r)" python3-gi gir1.2-adw-1 gir1.2-gtk-4.0 >/dev/null
elif command -v pacman >/dev/null; then
    # Headers do kernel em execução: linux -> linux-headers, linux-zen -> linux-zen-headers...
    KPKG=$(pacman -Qqo "/usr/lib/modules/$(uname -r)/vmlinuz" 2>/dev/null || echo linux)
    pacman -S --needed --noconfirm dkms "$KPKG-headers" python-gobject gtk4 libadwaita >/dev/null
else
    echo "Gerenciador de pacotes não suportado (use apt ou pacman)." >&2
    echo "Instale manualmente: dkms, headers do kernel, PyGObject, GTK4 e libadwaita." >&2
    exit 1
fi

echo ">> Driver (DKMS)"
if dkms status -m avell-dchu -v "$VER" | grep -q .; then
    modprobe -r avell_dchu 2>/dev/null || true
    dkms remove -m avell-dchu -v "$VER" --all >/dev/null || true
fi
rm -rf "$SRC"; mkdir -p "$SRC"
cp driver/avell_dchu.c driver/avell_dchu_ioctl.h driver/Makefile driver/dkms.conf "$SRC"/
dkms install -m avell-dchu -v "$VER"
install -Dm644 data/avell-dchu.conf /etc/modules-load.d/avell-dchu.conf

echo ">> Aplicativo"
rm -rf /usr/lib/avell-cc
install -d /usr/lib/avell-cc/avell_cc
install -m644 avell_cc/*.py /usr/lib/avell-cc/avell_cc/
install -Dm755 bin/avell-cc-helper /usr/libexec/avell-cc/avell-cc-helper
install -Dm755 bin/avellctl /usr/bin/avellctl
install -Dm755 bin/avell-control-center /usr/bin/avell-control-center
install -Dm644 data/br.com.avell.controlcenter.policy /usr/share/polkit-1/actions/br.com.avell.controlcenter.policy
install -Dm644 data/avell-control-center.desktop /usr/share/applications/avell-control-center.desktop
install -Dm644 data/avell-cc-restore.service /etc/systemd/system/avell-cc-restore.service
install -d -m755 /var/lib/avell-cc

systemctl daemon-reload
systemctl enable avell-cc-restore.service >/dev/null

echo ">> Carregando driver"
modprobe avell_dchu
sleep 1
/usr/libexec/avell-cc/avell-cc-helper restore >/dev/null 2>&1 || true
dmesg | grep -i avell | tail -5 || true
echo
avellctl status || true
echo
echo "Pronto. Abra \"Avell Control Center\" no menu de aplicativos."
