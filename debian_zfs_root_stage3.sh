## start of stage 3
echo "Starting stage3.  Unmounting filesystems and rebooting.\n"
## 6.3 Unmount filesystems
mount | grep -v zfs | tac | awk '/\/mnt/ {print $3}' | xargs -i{} umount -lf {}
zpool export rpool

## 6.4 Reboot
echo "Reboot.\n"
#reboot

## end of stage 3
