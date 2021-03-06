
HARDDISK=ata-VBOX_HARDDISK_VB882956a1-a319cf41
HOSTNAME=ubuntu
IFDEVICE=enp0s3

## 1. Prepare the install environment

## 1.1 Boot the livecd, username user and password live

## 1.2 Optional start OpenSSH server in LiveCD env
echo "==> Starting stage1.\n"

## 1.3 Become root
echo "==> Run as root.\n"
#sudo -i

## 1.4 add contrib
echo "==> Adding universe to sources.list.\n"
sudo apt-add-repository universe
apt update
apt install --yes vim git htop

## 1.5 install ZFS in the Live CD env
echo "==> Installing ZFS in the Live CD environment.\n"
apt install --yes debootstrap gdisk linux-headers-$(uname -r) zfs-initramfs

## 2. Disk Formatting
echo "==> Formatting disks.\n"

## clear previous partitions
echo "==> Clearing previous partitions.\n"
apt install --yes mdadm
#mdadm --zero-superblock --force /dev/disk/by-id/${HARDDISK}
sgdisk --zap-all /dev/disk/by-id/${HARDDISK}

## BIOS boot
echo "==> Creating BIOS boot partition.\n"
sgdisk -a1 -n2:34:2047  -t2:EF02 /dev/disk/by-id/${HARDDISK}
## UEFI boot
echo "==> UEFI partition.\n"
 sgdisk     -n3:1M:+512M -t3:EF00 /dev/disk/by-id/${HARDDISK}

## unencrypted or cCryptfs
#echo "==> Creating standard partition and ZFS pool (no LUKS).\n"
#sgdisk     -n1:0:0      -t1:BF01 /dev/disk/by-id/${HARDDISK}
#echo "==> Waiting for udev..."
#sleep 1
#zpool create -o ashift=12 -O atime=off -O canmount=off -O compression=lz4 -O normalization=formD -O mountpoint=/ -R /mnt rpool /dev/disk/by-id/${HARDDISK}-part1


## LUKS
apt install --yes cryptsetup
echo "==> Creating boot and LUKS partition.\n"
sgdisk     -n4:0:+512M  -t4:8300 /dev/disk/by-id/${HARDDISK}
sgdisk     -n1:0:0      -t1:8300 /dev/disk/by-id/${HARDDISK}
echo "==> Waiting for udev..."
sleep 1
cryptsetup luksFormat -c aes-xts-plain64 -s 256 -h sha256 /dev/disk/by-id/${HARDDISK}-part1
cryptsetup luksOpen /dev/disk/by-id/${HARDDISK}-part1 luks1

echo "==> Creating ZFS pool.\n"
zpool create -o ashift=12 -O atime=off -O canmount=off -O compression=lz4 -O normalization=formD -O mountpoint=/ -R /mnt rpool /dev/mapper/luks1

## 3. System Installation

echo "==> Starting system installation.\n"
## 3.1 create container
echo "==> Creating zfs container.\n"
zfs create -o canmount=off -o mountpoint=none rpool/ROOT

## 3.2 filesystem dataset
echo "==> Creating zfs filesystem dataset.\n"
zfs create -o canmount=noauto -o mountpoint=/ rpool/ROOT/ubuntu
zfs mount rpool/ROOT/ubuntu

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
echo "==> Format and mount boot partition.\n"
mke2fs -t ext2 /dev/disk/by-id/${HARDDISK}-part4
mkdir /mnt/boot
mount /dev/disk/by-id/${HARDDISK}-part4 /mnt/boot

## 3.5 Install the minimal system
echo "==> Installing minimal system.\n"
chmod 1777 /mnt/var/tmp
debootstrap artful /mnt
zfs set devices=off rpool

## 4 System Configuration
echo "==> System configuration.\n"

## 4.1 Configure the hostname

echo "==> Setting hostname.\n"
echo ${HOSTNAME} > /mnt/etc/hostname

## 4.2 Configure the network interface
echo "==> Configuring network interface.\n"
echo "127.0.1.1       ubuntu" >> /etc/hosts
cat >> /mnt/etc/netplan/${IFDEVICE}.yaml << EOF
network:
  version: 2
  ethernets:
    ${IFDEVICE}:
      dhcp4: true
EOF

## 4.3 Configure sources
echo "==> Configuring sources.\n"
cat >> /mnt/etc/apt/sources.list << EOF
deb http://archive.ubuntu.com/ubuntu artful main universe
deb-src http://archive.ubuntu.com/ubuntu artful main universe

deb http://security.ubuntu.com/ubuntu artful-security main universe
deb-src http://security.ubuntu.com/ubuntu artful-security main universe

deb http://archive.ubuntu.com/ubuntu artful-updates main universe
deb-src http://archive.ubuntu.com/ubuntu artful-updates main universe
EOF
## 4.4 Bind mount virtual filesystems to new system and chroot

echo "==> Bind mounting virtual filesystems for new system.\n"
mount --rbind /dev  /mnt/dev
mount --rbind /proc /mnt/proc
mount --rbind /sys  /mnt/sys
cp -av /home/xubuntu/debian_zfs_root /mnt/root

echo "==> Finished with stage1.  Now chrooting to new environment for stage2.\n"
chroot /mnt /bin/bash --login
## end of stage 1

## start of stage 3
echo "==> Starting stage3.  Unmounting filesystems and rebooting.\n"
## 6.3 Unmount filesystems
mount | grep -v zfs | tac | awk '/\/mnt/ {print $3}' | xargs -i{} umount -lf {}
zpool export rpool

## 6.4 Reboot
echo "==> Reboot.\n"
#reboot

## end of stage 3
