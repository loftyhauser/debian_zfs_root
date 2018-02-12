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
