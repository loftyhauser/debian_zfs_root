####### TROUBLESHOOTING #########

## Become root and install ZFS utilities
sudo -i
echo "deb http://ftp.debian.org/debian stretch main contrib" > /etc/apt/sources.list
apt update
apt install --yes debootstrap gdisk linux-headers-$(uname -r)
apt install --yes zfs-dkms

## Export ZFS and reimport to get mounts right
 zpool export -a
 zpool import -N -R /mnt rpool
 zfs mount rpool/ROOT/debian
 zfs mount -a

## Chroot
 mount --rbind /dev  /mnt/dev
 mount --rbind /proc /mnt/proc
 mount --rbind /sys  /mnt/sys
 chroot /mnt /bin/bash --login

## Once finished, cleanup
 mount | grep -v zfs | tac | awk '/\/mnt/ {print $3}' | xargs -i{} umount -lf {}
 zpool export rpool
 reboot
