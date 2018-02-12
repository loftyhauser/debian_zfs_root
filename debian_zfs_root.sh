
HARDDISK = ata-VBOX_HARDDISK_VB882956a1-a319cf41
HOSTNAME = debian
IFDEVICE = enp0s3

## 1. Prepare the install environment

## 1.1 Boot the livecd, username user and password live

## 1.2 Optional start OpenSSH server in LiveCD env
echo "Starting stage1.\n"

#$ sudo sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/g" /etc/ssh/sshd_config
#$ sudo service ssh restart

## 1.3 Become root
echo "Becoming root.\n"
sudo -i

## 1.4 add contrib
echo "Adding contrib to sources.list.\n"
echo "deb http://ftp.debian.org/debian stretch main contrib" > /etc/apt/sources.list
apt update

## 1.5 install ZFS in the Live CD env
echo "Installing ZFS in the Live CD environment.\n"
apt install --yes debootstrap gdisk linux-headers-$(uname -r)
apt install --yes zfs-dkms zfs-initramfs

## 2. Disk Formatting
echo "Formatting disks.\n"

## clear previous partitions
echo "Clearing previous partitions.\n"
apt install --yes mdadm
mdadm --zero-superblock --force /dev/disk/by-id/${HARDDISK}
sgdisk --zap-all /dev/disk/by-id/${HARDDISK}

## BIOS boot
echo "Creating BIOS boot partition.\n"
gdisk -a1 -n2:34:2047  -t2:EF02 /dev/disk/by-id/${HARDDISK}
## EFI boot
# sgdisk     -n3:1M:+512M -t3:EF00 /dev/disk/by-id/${HARDDISK}

## unencrypted or cCryptfs
echo "Creating standard partition and ZFS pool (no LUKS).\n"
 sgdisk     -n1:0:0      -t1:BF01 /dev/disk/by-id/${HARDDISK}
 zpool create -o ashift=12 -O atime=off -O canmount=off -O compression=lz4 -O normalization=formD -O mountpoint=/ -R /mnt rpool /dev/disk/by-id/${HARDDISK}-part1


## LUKS
#sgdisk     -n4:0:+512M  -t4:8300 /dev/disk/by-id/${HARDDISK}
#sgdisk     -n1:0:0      -t1:8300 /dev/disk/by-id/${HARDDISK}
#cryptsetup luksFormat -c aes-xts-plain64 -s 256 -h sha256 /dev/disk/by-id/${HARDDISK}-part1
#cryptsetup luksOpen /dev/disk/by-id/${HARDDISK}-part1 luks1

#zpool create -o ashift=12 -O atime=off -O canmount=off -O compression=lz4 -O normalization=formD -O mountpoint=/ -R /mnt rpool /dev/mapper/luks1

## 3. System Installation

echo "Starting system installation.\n"
## 3.1 create container
echo "Creating zfs container.\n"
zfs create -o canmount=off -o mountpoint=none rpool/ROOT

## 3.2 filesystem dataset
echo "Creating zfs filesystem dataset.\n"
zfs create -o canmount=noauto -o mountpoint=/ rpool/ROOT/debian
zfs mount rpool/ROOT/debian
## Not sure if this is needed...
zpool set bootfs=rpool/ROOT/debian rpool

## 3.3 Create datasets
zfs create                 -o setuid=off              rpool/home
zfs create -o mountpoint=/root                        rpool/home/root
zfs create -o canmount=off -o setuid=off  -o exec=off rpool/var
zfs create -o com.sun:auto-snapshot=false             rpool/var/cache
zfs create                                            rpool/var/log
zfs create                                            rpool/var/spool
zfs create -o com.sun:auto-snapshot=false -o exec=on  rpool/var/tmp

#If you use /srv on this system:
# zfs create                                            rpool/srv

#If this system will have games installed:
# zfs create                                            rpool/var/games

#If this system will store local email in /var/mail:
# zfs create                                            rpool/var/mail

#If this system will use NFS (locking):
# zfs create -o com.sun:auto-snapshot=false -o mountpoint=/var/lib/nfs                 rpool/var/nfs

## For LUKS install only
# mke2fs -t ext2 /dev/disk/by-id/${HARDDISK}-part4
# mkdir /mnt/boot
# mount /dev/disk/by-id/${HARDDISK}-part4 /mnt/boot

## 3.5 Install the minimal system
echo "Installing minimal system.\n"
chmod 1777 /mnt/var/tmp
debootstrap stretch /mnt
zfs set devices=off rpool

## 4 System Configuration
echo "System configuration.\n"

## 4.1 Configure the hostname

echo "Setting hostname.\n"
echo ${HOSTNAME} > /mnt/etc/hostname

## 4.2 Configure the network interface
echo "Configuring network interface.\n"
echo "127.0.1.1       debian" >> /etc/hosts
cat > /mnt/etc/network/interfaces.d/${IFDEVICE} < EOF
auto ${IFDEVICE}
iface ${IFDEVICE} inet dhcp
EOF

## 4.3 Bind mount virtual filesystems to new system and chroot

echo "Bind mounting virtual filesystems for new system.\n"
mount --rbind /dev  /mnt/dev
mount --rbind /proc /mnt/proc
mount --rbind /sys  /mnt/sys
cp debian_zfs_root_stage2.sh /mnt/root

echo"Finished with stage1.  Now chrooting to new environment for stage2.\n"
chroot /mnt /bin/bash --login
## end of stage 1

## start of stage 2
HARDDISK = ata-VBOX_HARDDISK_VB882956a1-a319cf41

echo "Starting stage2 in chrooted environment.\n"
######### IN CHROOTED ENV ########################
## 4.4 Configure basic system environment

echo "Adding contrib to sources.list in chroot.\n"
echo "deb http://ftp.debian.org/debian stretch main contrib" >> /etc/apt/sources.list
echo "deb-src http://ftp.debian.org/debian stretch main contrib" >> /etc/apt/sources.list

echo "Adding /etc/mtab and updating.\n"
ln -s /proc/self/mounts /etc/mtab
apt update

echo "Configuring locale.\n"
apt install --yes locales
#dpkg-reconfigure locales
locale-gen en_US.UTF-8
echo LANG=en_US.UTF-8 > /etc/default/locale

echo "Configuring timezone.\n"
dpkg-reconfigure tzdata

echo "Installing needed packages (including kernel) in chroot.\n"
apt install --yes gdisk linux-headers-$(uname -r) linux-image-amd64

## 4.5 Install ZFS in chroot env

apt install --yes zfs-dkms zfs-initramfs

### LUKS ONLY
# echo UUID=$(blkid -s UUID -o value /dev/disk/by-id/${HARDDISK}-part4) /boot ext2 defaults 0 2 >> /etc/fstab

# apt install --yes cryptsetup

# echo luks1 UUID=$(blkid -s UUID -o value /dev/disk/by-id/${HARDDISK}-part1) none luks,discard,initramfs > /etc/crypttab

## 4.6 Install GRUB

## MBR booting
echo "Installing grub for MBR booting.\n"
apt install --yes grub-pc

## EFI booting
# apt install dosfstools
# mkdosfs -F 32 -n EFI /dev/disk/by-id/${HARDDISK}-part3
# mkdir /boot/efi
# echo PARTUUID=$(blkid -s PARTUUID -o value /dev/disk/by-id/${HARDDISK}-part3) /boot/efi vfat defaults 0 1 >> /etc/fstab
# mount /boot/efi
# apt install --yes grub-efi-amd64

## 4.7 Set root password
echo "Setting root password.\n"
passwd

## 4.8 Filesystem mount ordering (not sure if needed in Debian)
echo "Filesystem mount ordering (systemd doesn't understand zfs).\n"
zfs set mountpoint=legacy rpool/var/log
zfs set mountpoint=legacy rpool/var/tmp
cat >> /etc/fstab << EOF
rpool/var/log /var/log zfs defaults 0 0
rpool/var/tmp /var/tmp zfs defaults 0 0
EOF

## 5. GRUB installation

## 5.1 Verify that ZFS root is recognized

echo "Verifying that ZFS is recognized by grub: should return 'zfs'.\n"
grub-probe /
# should return: zfs

## 5.2 Refresh initrd
echo "Updating the initramfs.\n"
#update-initramfs -u -k all
# or
update-initramfs -c -k all

## 5.3 (Optional) make debugging GRUB easier

echo "Updating grub options.  Remove 'quiet' and set terminal to 'console'"
vi /etc/default/grub
#Remove quiet from: GRUB_CMDLINE_LINUX_DEFAULT
#Uncomment: GRUB_TERMINAL=console
#Save and quit.

## 5.4 Update the boot configuration
echo "Updating grub.\n"
update-grub

## 5.5 Install boot loader

## MBR booting
echo "Installing grub for MBR booting.\n"
grub-install /dev/disk/by-id/${HARDDISK}

## UEFI booting
# grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=debian --recheck --no-floppy

## 5.6 Verify that ZFS module is installed
echo "Verifying that ZFS module is installed.  Should see zfs.mod.\n"
ls /boot/grub/*/zfs.mod

## 6. First Boot

## 6.1 Snapshot initial installation
echo "Taking initial installation ZFS snapshot.\n"
zfs snapshot rpool/ROOT/debian@install

## 6.2 Exit from chroot
echo "Finished stage2; exiting from chroot...\n"
exit

## end of stage 2

## start of stage 3
echo "Starting stage3.  Unmounting filesystems and rebooting.\n"
## 6.3 Unmount filesystems
mount | grep -v zfs | tac | awk '/\/mnt/ {print $3}' | xargs -i{} umount -lf {}
zpool export rpool

## 6.4 Reboot
echo "Reboot.\n"
#reboot

## end of stage 3

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

## 9. Final Cleanup
echo "Starting stage 5, Final Cleanup.\n"

## 9.1 Wait for system to boot normally.  Log in as normal user.  Ensure system works (including networking.

## 9.2 (Optional) Delete snapshot of initial installation
echo "Deleting snapshot of initial installation.\n"
sudo zfs destroy rpool/ROOT/debian@install

## 9.3 (Optional) Disable root password

echo "Disabling root password.\n"
sudo usermod -p '*' root

## 9.4 (Optional) Graphical boot process
echo "Restore graphical boot in grub.  Add quiet and comment out console.\n"
sudo vi /etc/default/grub
#Add quiet to GRUB_CMDLINE_LINUX_DEFAULT
#Comment out GRUB_TERMINAL=console
#Save and quit.

sudo update-grub

echo "All done!"
####### TROUBLESHOOTING #########

## Become root and install ZFS utilities
#echo "deb http://ftp.debian.org/debian stretch main contrib" > /etc/apt/sources.list
#apt update
#apt install --yes debootstrap gdisk linux-headers-$(uname -r)
#apt install --yes zfs-dkms

## Export ZFS and reimport to get mounts right
# zpool export -a
# zpool import -N -R /mnt rpool
# zfs mount rpool/ROOT/debian
# zfs mount -a

## Chroot
# mount --rbind /dev  /mnt/dev
# mount --rbind /proc /mnt/proc
# mount --rbind /sys  /mnt/sys
# chroot /mnt /bin/bash --login

## Once finished, cleanup
# mount | grep -v zfs | tac | awk '/\/mnt/ {print $3}' | xargs -i{} umount -lf {}
# zpool export rpool
# reboot
