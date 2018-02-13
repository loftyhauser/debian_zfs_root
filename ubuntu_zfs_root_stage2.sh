## start of stage 2
HARDDISK=ata-VBOX_HARDDISK_VB882956a1-a319cf41

echo "==> Starting stage2 in chrooted environment.\n"
######### IN CHROOTED ENV ########################
## 4.4 Configure basic system environment

echo "==> Configuring locale.\n"
locale-gen en_US.UTF-8
echo LANG=en_US.UTF-8 > /etc/default/locale

echo "==> Configuring timezone.\n"
dpkg-reconfigure tzdata

echo "==> Adding /etc/mtab and updating.\n"
ln -s /proc/self/mounts /etc/mtab
apt update

echo "==> Installing needed packages (including kernel) in chroot.\n"
apt install --yes --no-install-recommends linux-image-generic vim

## 4.5 Install ZFS in chroot env

apt install --yes zfs-initramfs

### LUKS ONLY
echo "==> LUKS configuration (boot partition and crypttab).\n"
echo UUID=$(blkid -s UUID -o value /dev/disk/by-id/${HARDDISK}-part4) /boot ext2 defaults 0 2 >> /etc/fstab

apt install --yes cryptsetup

echo luks1 UUID=$(blkid -s UUID -o value /dev/disk/by-id/${HARDDISK}-part1) none luks,discard,initramfs > /etc/crypttab

## 4.6 Install GRUB

## MBR booting
#echo "==> Installing grub for MBR booting.\n"
#apt install --yes grub-pc

## UEFI booting
echo "==> UEFI boot support.\n"
apt install dosfstools
mkdosfs -F 32 -n EFI /dev/disk/by-id/${HARDDISK}-part3
mkdir /boot/efi
echo PARTUUID=$(blkid -s PARTUUID -o value /dev/disk/by-id/${HARDDISK}-part3) /boot/efi vfat nofail,x-systemd.device-timeout=1 0 1 >> /etc/fstab
mount /boot/efi
apt install --yes grub-efi-amd64

echo "==> Setting up system groups.\n"
addgroup --system lpadmin
addgroup --system sambashare

## 4.7 Set root password
echo "==> Setting root password.\n"
passwd

## 4.8 Filesystem mount ordering (not sure if needed in Debian)
echo "==> Filesystem mount ordering (systemd doesn't understand zfs).\n"
zfs set mountpoint=legacy rpool/var/log
zfs set mountpoint=legacy rpool/var/tmp
cat >> /etc/fstab << EOF
rpool/var/log /var/log zfs defaults 0 0
rpool/var/tmp /var/tmp zfs defaults 0 0
EOF

## 5. GRUB installation

## 5.1 Verify that ZFS root is recognized

echo "==> Verifying that ZFS is recognized by grub: should return 'zfs'.\n"
grub-probe /
# should return: zfs

## 5.2 Refresh initrd
echo "==> Updating the initramfs.\n"
#update-initramfs -u -k all
# or
update-initramfs -c -k all

## 5.3 (Optional) make debugging GRUB easier

echo "==> Updating grub options.  Comment GRUB_HIDDEN_TIMEOUT, remove 'quiet' and 'splash' and set terminal to 'console'"
vim /etc/default/grub
#Comment GRUB_HIDDEN_TIMEOUT=0
#Remove quiet and splash from: GRUB_CMDLINE_LINUX_DEFAULT
#Uncomment: GRUB_TERMINAL=console
#Save and quit.

## 5.4 Update the boot configuration
echo "==> Updating grub.\n"
update-grub

## 5.5 Install boot loader

## MBR booting
#echo "==> Installing grub for MBR booting.\n"
#grub-install /dev/disk/by-id/${HARDDISK}

## UEFI booting
echo "==> Installing grub for UEFI booting.\n"
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ubuntu --recheck --no-floppy

## 5.6 Verify that ZFS module is installed
echo "==> Verifying that ZFS module is installed.  Should see zfs.mod.\n"
ls /boot/grub/*/zfs.mod

## 6. First Boot

## 6.1 Snapshot initial installation
echo "==> Taking initial installation ZFS snapshot.\n"
zfs snapshot rpool/ROOT/ubuntu@install

## 6.2 Exit from chroot
echo "==> Finished stage2; exiting from chroot...\n"
exit

## end of stage 2
