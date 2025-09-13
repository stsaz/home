echo "Configuration script for Fedora 42"
# REVIEW COMMANDS BEFORE EXECUTING! SOME CHANGES CANNOT BE REVERTED!

set -e

: ${VERBOSE:=0}
if test "$VERBOSE" == "1" ; then
	set -x
fi

CMDS_ALL=(
	timezone_set
	swap_disable
	selinux_disable
	syslog_disable # disable system logging
	services_disable # remove/disable default services
	iptables_autoload_setup

	repo_default_disable
	repo_rpmfusion_install

	hw_info_print
	hw_camera_disable
	hw_bluetooth_disable
	hw_intel_gpu_install
	hw_amd_gpu_hwaccel
	hw_battery_max_charge_95_percent
	hw_speaker_disable
	hw_time_sync_once

	kde_services_disable
	kde_apps_erase
	kde_perf # configure kde environment for max performance
	kde_misc # change misc. kde settings

	lxqt_install
	lxqt_apps_default_erase
	lxqt_dark
	lxqt_autologin

	user_cache_tmp
	user_bashrc_conf

	cdevel_setup
	user_git_dark
)

CMDS_DEF=(
	timezone_set
	swap_disable
	selinux_disable
	syslog_disable
	services_disable

	# kde_apps_erase
	lxqt_apps_default_erase

	user_cache_tmp
	user_bashrc_conf
	lxqt_autologin
)

TIME_ZONE="/usr/share/zoneinfo/Europe/London"

APPS_ERASE_KDE=(
	audit dnfdragora
	plasma-discover* sssd-kcm
	libreoffice-math libreoffice-draw libreoffice-impress
	abrt-gui ghostscript elisa-player nfs-utils
	akonadi* kf5-akonadi* kf5-baloo-file
	PackageKit dragon kdeconnectd krfb kmahjongg kpat kmines kmousetool kmag kmouth kfind krdc
	konversation speech-dispatcher plasma-workspace-wallpapers
)

if test "$#" -eq 0 ; then
	echo "Supported commands: ${CMDS_ALL[@]}"
	echo "Default commands: ${CMDS_DEF[@]}"
	exit 1
fi

CMDS=("$@")
if test "$1" == "default" ; then
	CMDS=("${CMDS_DEF[@]}")
fi


timezone_set() {
	echo "set time zone"
	sudo ln -s -f $TIME_ZONE /etc/localtime
}

swap_disable() {
	echo "disable swap"
	sudo swapoff -a
	sudo dnf remove -y zram-generator
}

selinux_disable() {
	echo "disable SELinux"
	# disable SELinux policy, but SELinux will still be running
	# sudo sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/sysconfig/selinux
	echo "add kernel option to /boot/loader/entries/*"
	sudo grubby --update-kernel ALL --args selinux=0
	sudo rm -rf /var/lib/selinux
}

syslog_disable() {
	echo "disable system logging"
	sudo systemctl disable rsyslog
	sudo sed -i 's/#Storage=auto/Storage=none/' /usr/lib/systemd/journald.conf
	sudo sed -i 's/#SystemMaxUse=/SystemMaxUse=0/' /usr/lib/systemd/journald.conf
	sudo systemctl daemon-reload
	sudo rm -rf /var/log/*
}

services_disable() {
	echo "disable services"
	sudo systemctl disable crond
	sudo systemctl disable smartd
	sudo systemctl disable firewalld
	sudo systemctl disable abrtd
	sudo systemctl disable dnf-makecache.timer
	sudo systemctl disable dnf-makecache.service
	sudo systemctl mask systemd-oomd
	sudo rm -rf /var/spool/abrt /var/lib/systemd/coredump

	echo "disable creation of core dumps in /var/lib/systemd/coredump/"
	sudo sed -i 's/fs.suid_dumpable=2/fs.suid_dumpable=0/' /usr/lib/sysctl.d/50-coredump.conf
}

iptables_autoload_setup() {
	sudo dnf install iptables-services
	sudo systemctl start iptables
	sudo systemctl enable iptables
	sudo systemctl status iptables
	sudo iptables-save | sudo tee /etc/sysconfig/iptables
}

dnf_config() {
	sudo dnf config-manager setopt \
		updates.enabled=0 \
		fedora-cisco-openh264.enabled=0
	sudo dnf install -y \
		https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
	sudo dnf config-manager setopt \
		rpmfusion-free.enabled=0 \
		rpmfusion-free-updates.enabled=0
	# https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
	sudo dnf repolist --all
}

cdevel_setup() {
	echo "developer stuff"

	echo "allow 'gdb --pid PID' under normal user"
	echo 'kernel.yama.ptrace_scope = 0' | sudo tee -a /etc/sysctl.d/10-ptrace.conf

	sudo rm /etc/profile.d/debuginfod.sh /etc/profile.d/debuginfod.csh

	echo 'set breakpoint pending on
set confirm off' >>~/.gdbinit
}


hw_info_print() {
	uname -a
	lscpu
	lsmem
	lspci
	glxinfo|grep -A12 'Extended renderer info'
	lsblk
	sudo fdisk -l
	df
}

hw_intel_gpu_install() {
	echo "install driver, intel_gpu_top"
	sudo dnf --enable-repo=rpmfusion-free --enable-repo=rpmfusion-free-updates \
		install -y \
		libva-intel-driver igt-gpu-tools
	sudo dnf remove libva-intel-media-driver
}

hw_amd_gpu_hwaccel() {
	sudo dnf swap --enable-repo=rpmfusion-free --enable-repo=rpmfusion-free-updates \
		mesa-va-drivers mesa-va-drivers-freeworld
	# sudo dnf update mesa-*
}

hw_battery_max_charge_95_percent() {
	echo 95 | sudo tee /sys/class/power_supply/BAT0/charge_control_end_threshold
	echo 'echo 95 > /sys/class/power_supply/BAT0/charge_control_end_threshold' | sudo tee -a /sbin/init_user_cache.sh
}

hw_camera_disable() {
	echo "blacklist uvcvideo" | sudo tee -a /etc/modprobe.d/blacklist.conf
}

hw_speaker_disable() {
	echo 'blacklist pcspkr' | sudo tee -a /etc/modprobe.d/blacklist.conf
}

hw_bluetooth_disable() {
	echo "disable bluetooth"
 	sudo systemctl disable bluetooth
	echo "blacklist bluetooth
blacklist btusb
blacklist btrtl
blacklist btbcm
blacklist btintel" | sudo tee -a /etc/modprobe.d/blacklist.conf
}

hw_time_sync_once() {
	timedatectl
	sudo timedatectl set-ntp true
	sudo systemctl start systemd-timesyncd
	sudo systemctl status systemd-timesyncd
	sleep 1
	sudo systemctl stop systemd-timesyncd
	timedatectl
}


user_git_dark() {
	echo "Set dark colors for git-gui and gitk"
	sudo patch /usr/share/git-gui/lib/themed.tcl < gitgui-dark.patch
	mkdir -p ~/.config/git
	cp -a ./gitk-dark ~/.config/git/gitk
}

user_cache_tmp() {
	echo "set up user cache in /tmp"
	USER_ID=$(id -u)
	echo "mkdir -p /tmp/1
chmod 777 /tmp/1

mkdir -p /tmp/u${USER_ID}_cache
chown ${USER_ID}:${USER_ID} /tmp/u${USER_ID}_cache" | sudo tee /sbin/init_user_cache.sh
	echo "[Unit]
Description=Create user cache directory
DefaultDependencies=false
After=multi-user.target

[Service]
Type=simple
ExecStart=/bin/sh /sbin/init_user_cache.sh

[Install]
WantedBy=multi-user.target" | sudo tee /usr/lib/systemd/system/user_init_cache.service
	sudo systemctl enable user_init_cache
	sh /sbin/init_user_cache.sh
	rm -rf ~/.cache
	ln -s /tmp/u${USER_ID}_cache ~/.cache
}

user_bashrc_conf() {
	echo "configure bashrc"
	mkdir -p ~/.bashrc.d
	cp -ru .bashrc.d/* ~/.bashrc.d/
}


kde_apps_erase() {
	echo "erase packages"
	sudo dnf erase -y "${APPS_ERASE_KDE[@]}"
	sudo rm -rf '/usr/share/wallpapers/Next/'
	rm -rf ~/.local/share/akonadi ~/.config/akonadi
}

kde_services_disable() {
	sudo balooctl disable

	echo "backup autostart scripts to ~/xdg-autostart-backup.tgz and then delete them"
	AUTOSTART_FILES="at-spi-dbus-bus.desktop \
baloo_file.desktop \
geoclue-demo-agent.desktop \
gmenudbusmenuproxy.desktop \
gnome-keyring-pkcs11.desktop \
gnome-keyring-secrets.desktop \
gnome-keyring-ssh.desktop \
imsettings-start.desktop \
kaccess.desktop \
klipper.desktop \
liveinst-setup.desktop \
org.freedesktop.problems.applet.desktop \
org.kde.discover.notifier.desktop \
org.kde.kalendarac.desktop \
org.kde.kdeconnect.daemon.desktop \
org.kde.kgpg.desktop \
org.kde.plasma-welcome.desktop \
pam_kwallet_init.desktop \
polkit-kde-authentication-agent-1.desktop \
spice-vdagent.desktop \
vboxclient.desktop \
vmware-user.desktop \
xdg-user-dirs.desktop \
xdg-user-dirs-kde.desktop \
xembedsniproxy.desktop \
"
	tar -C /etc/xdg/autostart -czf ~/xdg-autostart-backup.tgz $AUTOSTART_FILES
	cd /etc/xdg/autostart && sudo rm -vf $AUTOSTART_FILES && cd -
}

kde_perf() {
	echo "configure kde environment for max performance"
	kwriteconfig5 --file breezerc --group 'Common' --key 'ShadowSize' 'ShadowNone'
	kwriteconfig5 --file breezerc --group 'Common' --key 'OutlineCloseButton' 'true'
	kwriteconfig5 --file breezerc --group 'Windeco' --key 'DrawBackgroundGradient' 'false'
	kwriteconfig5 --file ksplashrc --group 'KSplash' --key 'Engine' 'none'
	kwriteconfig5 --file ksplashrc --group 'KSplash' --key 'Theme' 'None'
	kwriteconfig5 --file kwinrc --group 'TabBox' --key 'HighlightWindows' 'false'
	kwriteconfig5 --file kwinrc --group 'TabBox' --key 'LayoutName' 'big_icons'
	kwriteconfig5 --file dolphinrc --group 'PreviewSettings' --key 'Plugins' ''
	kwriteconfig5 --file krunnerrc --group 'Plugins' --key 'baloosearchEnabled' 'false'
	kwriteconfig5 --file kuriikwsfilterrc --group 'General' --key 'EnableWebShortcuts' 'false'

	echo "disable all animations"
	kwriteconfig5 --file breezerc --group 'Style' --key 'AnimationsEnabled' 'false'
	kwriteconfig5 --file breezerc --group 'Windeco' --key 'AnimationsEnabled' 'false'
	kwriteconfig5 --file kwinrc --group 'Plugins' --key 'blurEnabled' 'false'
	kwriteconfig5 --file kwinrc --group 'Plugins' --key 'contrastEnabled' 'false'
	kwriteconfig5 --file kwinrc --group 'Plugins' --key 'desktopgridEnabled' 'false'
	kwriteconfig5 --file kwinrc --group 'Plugins' --key 'kwin4_effect_dialogparentEnabled' 'false'
	kwriteconfig5 --file kwinrc --group 'Plugins' --key 'kwin4_effect_fadeEnabled' 'false'
	kwriteconfig5 --file kwinrc --group 'Plugins' --key 'kwin4_effect_fadingpopupsEnabled' 'false'
	kwriteconfig5 --file kwinrc --group 'Plugins' --key 'kwin4_effect_frozenappEnabled' 'false'
	kwriteconfig5 --file kwinrc --group 'Plugins' --key 'kwin4_effect_fullscreenEnabled' 'false'
	kwriteconfig5 --file kwinrc --group 'Plugins' --key 'kwin4_effect_loginEnabled' 'false'
	kwriteconfig5 --file kwinrc --group 'Plugins' --key 'kwin4_effect_logoutEnabled' 'false'
	kwriteconfig5 --file kwinrc --group 'Plugins' --key 'kwin4_effect_maximizeEnabled' 'false'
	kwriteconfig5 --file kwinrc --group 'Plugins' --key 'kwin4_effect_morphingpopupsEnabled' 'false'
	kwriteconfig5 --file kwinrc --group 'Plugins' --key 'kwin4_effect_squashEnabled' 'false'
	kwriteconfig5 --file kwinrc --group 'Plugins' --key 'kwin4_effect_translucencyEnabled' 'false'
	kwriteconfig5 --file kwinrc --group 'Plugins' --key 'kwin4_effect_windowapertureEnabled' 'false'
	kwriteconfig5 --file kwinrc --group 'Plugins' --key 'presentwindowsEnabled' 'false'
	kwriteconfig5 --file kwinrc --group 'Plugins' --key 'screenedgeEnabled' 'false'
	kwriteconfig5 --file kwinrc --group 'Plugins' --key 'slideEnabled' 'false'
	kwriteconfig5 --file kwinrc --group 'Plugins' --key 'slidingpopupsEnabled' 'false'
	kwriteconfig5 --file kwinrc --group 'Plugins' --key 'zoomEnabled' 'false'
}

kde_misc() {
	echo "change misc. kde settings"
	kwriteconfig5 --file breezerc --group 'Style' --key 'WindowDragMode' 'WD_NONE'
	kwriteconfig5 --file breezerc --group 'Windeco' --key 'ButtonSize' 'ButtonLarge'
	kwriteconfig5 --file dolphinrc --group 'General' --key 'ShowFullPath' 'true'
	kwriteconfig5 --file dolphinrc --group 'General' --key 'ShowFullPathInTitlebar' 'true'
	kwriteconfig5 --file dolphinrc --group 'General' --key 'UseTabForSwitchingSplitView' 'true'
	kwriteconfig5 --file dolphinrc --group 'KDE' --key 'SingleClick' 'true'
	kwriteconfig5 --file kcminputrc --group 'Mouse' --key 'cursorSize' '48'
	kwriteconfig5 --file kcminputrc --group 'Mouse' --key 'XLbInptAccelProfileFlat' 'true'
	kwriteconfig5 --file kcminputrc --group 'Mouse' --key 'XLbInptPointerAcceleration' -- '-0.6'
	kwriteconfig5 --file kcminputrc --group 'Keyboard' --key 'RepeatDelay' '220'
	kwriteconfig5 --file kcminputrc --group 'Keyboard' --key 'RepeatRate' '35'
	kwriteconfig5 --file kdeglobals --group 'KDE' --key 'AnimationDurationFactor' '0'
	kwriteconfig5 --file kdeglobals --group 'KDE' --key 'SingleClick' 'true'
	kwriteconfig5 --file kdeglobals --group 'KDE' --key 'widgetStyle' 'Fusion'
	kwriteconfig5 --file konsolerc --group 'TabBar' --key 'TabBarPosition' 'Top'
	kwriteconfig5 --file kscreenlockerrc --group 'Daemon' --key 'Autolock' 'false'
	kwriteconfig5 --file kscreenlockerrc --group 'Daemon' --key 'LockOnResume' 'false'
	kwriteconfig5 --file ksmserverrc --group 'General' --key 'loginMode' 'restorePreviousLogout'
	kwriteconfig5 --file kwinrc --group 'MouseBindings' --key 'CommandAll1' 'Nothing'
	kwriteconfig5 --file kwinrc --group 'org.kde.kdecoration2' --key 'BorderSizeAuto' 'false'
	kwriteconfig5 --file kwinrc --group 'org.kde.kdecoration2' --key 'ButtonsOnLeft' 'MF'
	kwriteconfig5 --file kxkbrc --group 'Layout' --key 'Options' 'grp:win_space_toggle'
	kwriteconfig5 --file kxkbrc --group 'Layout' --key 'ResetOldOptions' 'true'

	echo "remove default global key shortcuts"
	sed -i 's/Alt+Space\\tAlt+F2\\tSearch/none/' ~/.config/kglobalshortcutsrc
	sed -i 's/Ctrl+Alt+T/none/' ~/.config/kglobalshortcutsrc
	sed -i 's/Ctrl+Alt+K/none/' ~/.config/kglobalshortcutsrc
	sed -i 's/Ctrl+F1/none/' ~/.config/kglobalshortcutsrc
	sed -i 's/Ctrl+F2/none/' ~/.config/kglobalshortcutsrc
	sed -i 's/Ctrl+F3/none/' ~/.config/kglobalshortcutsrc
	sed -i 's/Ctrl+F4/none/' ~/.config/kglobalshortcutsrc
	sed -i 's/Alt+F3/none/' ~/.config/kglobalshortcutsrc

	echo "set global key shortcuts"
	kwriteconfig5 --file kglobalshortcutsrc --group 'kwin' --key 'Switch to Desktop 1' 'Meta+F1,Ctrl+F1,Switch to Desktop 1'
	kwriteconfig5 --file kglobalshortcutsrc --group 'kwin' --key 'Switch to Desktop 2' 'Meta+F2,Ctrl+F2,Switch to Desktop 2'
	kwriteconfig5 --file kglobalshortcutsrc --group 'kwin' --key 'Window to Desktop 1' 'Meta+Ctrl+F1,none,Window to Desktop 1'
	kwriteconfig5 --file kglobalshortcutsrc --group 'kwin' --key 'Window to Desktop 2' 'Meta+Ctrl+F2,none,Window to Desktop 2'
}


lxqt_install() {
	sudo dnf install @lxqt-desktop
	sudo systemctl set-default graphical.target
	sudo systemctl status sddm
}

lxqt_apps_default_erase() {
	sudo dnf remove -y \
		audit dnfdragora dnfdragora-updater plocate
	sudo killall -9 dnfdragora-updater || true
}

lxqt_autologin() {
	echo "[Autologin]
User=$USER
Session=lxqt" | sudo tee /etc/sddm.conf.d/autologin.conf

	# launch by 'startx'
	echo "exec startlxqt" >~/.xinitrc
	# echo "exec startplasma-wayland" > ~/.xinitrc
}


echo "check if normal user"
if test "`id -u`" == "0" ; then
	echo "Execute under normal user"
	exit
fi

for cmd in "${CMDS[@]}"; do
	$cmd
done

echo "Done"
