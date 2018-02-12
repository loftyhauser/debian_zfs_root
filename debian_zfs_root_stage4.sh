## start of stage 4
echo "Starting stage4.  System should have been rebooted.\n"

YOURUSERNAME = alofthou
## 6.5 Wait for system to boot.  Log in as root.

## 6.6 Create user account
echo "Creating user account ${YOURUSERNAME}.\n"
zfs create rpool/home/${YOURUSERNAME}
adduser ${YOURUSERNAME}
cp -a /etc/skel/.[!.]* /home/${YOURUSERNAME}
chown -R ${YOURUSERNAME}:${YOURUSERNAME} /home/${YOURUSERNAME}

## eCryptfs
# apt install ecryptfs-utils
# zfs create -o compression=off -o mountpoint=/home/.ecryptfs/YOURUSERNAME rpool/home/temp-YOURUSERNAME
# adduser --encrypt-home YOURUSERNAME
# zfs rename rpool/home/temp-YOURUSERNAME rpool/home/YOURUSERNAME

## 6.7 Add user account to defaults for admin
echo "Add user account to default groups for admins."
usermod -a -G audio,cdrom,dip,floppy,netdev,plugdev,sudo,video ${YOURUSERNAME}

## 7. Configure swap
echo "Configuring swap.\n"

## 7.1 Create zvol for swap
zfs create -V 4G -b $(getconf PAGESIZE) -o compression=zle -o logbias=throughput -o sync=always -o primarycache=metadata -o secondarycache=none -o com.sun:auto-snapshot=false rpool/swap

## 7.2 Configure swap device

## Unencrypted
mkswap -f /dev/zvol/rpool/swap
echo /dev/zvol/rpool/swap none swap defaults 0 0 >> /etc/fstab

## Encrypted (if using encrypted $HOME)
# echo cryptswap1 /dev/zvol/rpool/swap /dev/urandom swap,cipher=aes-xts-plain64:sha256,size=256 >> /etc/crypttab
# systemctl daemon-reload
# systemctl start systemd-cryptsetup@cryptswap1.service
# echo /dev/mapper/cryptswap1 none swap defaults 0 0 >> /etc/fstab

## 7.3 Enable swap device
swapon -av

## 8. Full Software Installation

## 8.1 upgrade minimal system
echo "Upgrade minimal system.\n"
apt dist-upgrade --yes

## 8.2 (Optional) Disable log compression
echo "Disabling log compression.\n"
for file in /etc/logrotate.d/* ; do
    if grep -Eq "(^|[^#y])compress" "$file" ; then
        sed -i -r "s/(^|[^#y])(compress)/\1#\2/" "$file"
    fi
done

## 8.3 Reboot

## end of stage 4
echo "Stage4 now complete.  Reboot.\n"
#reboot
