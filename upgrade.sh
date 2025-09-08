#!/bin/sh

HOST="https://raw.githubusercontent.com/hvanhung222/220/main"
KERNEL="kernel"
ROOTFS="root"

echo "Going to /tmp"
cd /tmp

echo "Cleaning up to get some extra space"
rm -rf /var/log/* /alarm*

echo "Downloading new firmware"
wget -O $KERNEL $HOST/$KERNEL
wget -O $ROOTFS $HOST/$ROOTFS

echo "Creating fw_env for uboot-envtools"
echo "/dev/mtd12 0x0000 0x10000 0x10000" > /etc/fw_env.config

echo "Setting primaryboot to partA"
echo 0 > /proc/boot_info/rootfs/primaryboot
mtd write /proc/boot_info/getbinary_bootconfig /dev/mtd5
mtd write /proc/boot_info/getbinary_bootconfig /dev/mtd10

echo "Disabling partB"
fw_setenv partAversion OpenWRT
fw_setenv partBversion Wi-Fi16A_AP.xx.xx.xx
# mtd erase /dev/mtd1

echo "Backing up MAC, SN to u-boot env"
fw_setenv ethaddr $(cat /proc/eidData/MACAddress | sed -e 's/\([0-9A-Fa-f]\{2\}\)/\1:/g' -e 's/\(.*\):$/\1/')
fw_setenv serialnumber $(cat /proc/eidData/SerialNumber)

echo "Detaching UBI"
ubidetach -p /dev/mtd0 -f 2> /dev/null
ubidetach -p /dev/mtd1 -f 2> /dev/null

echo "Creating new UBI in partA"
ubiformat /dev/mtd0 -y
ubiattach -p /dev/mtd0 

echo "Creating new UBI Volume"
ubimkvol /dev/ubi0 -s $(wc -c $KERNEL | awk '{print $1}') -N kernel 
ubimkvol /dev/ubi0 -s $(wc -c $ROOTFS | awk '{print $1}') -N ubi_rootfs 
ubimkvol /dev/ubi0 -m -N rootfs_data

echo "Writing image..."
ubiupdatevol /dev/ubi0_0 $KERNEL
ubiupdatevol /dev/ubi0_1 $ROOTFS

echo "Done, system will force reboot NOW!"
sleep 2

echo b > /proc/sysrq-trigger

