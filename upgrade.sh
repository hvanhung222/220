#!/bin/sh

# Google Drive file IDs
KERNEL_ID="1WpSzJxAfI5fV9P0GpW_tSRJdggS4hfCR"
ROOTFS_ID="1Dy3ytfcOSMUV9mbP8Q7tSUgqmKKLgBI7"

# Local filenames
KERNEL="openwrt-ipq40xx-generic-nokia_ac220i-squashfs-uImage.itb"
ROOTFS="openwrt-ipq40xx-generic-nokia_ac220i-squashfs-rootfs.sqsh"

download_from_gdrive() {
  FILE_ID="$1"
  OUTPUT_NAME="$2"

  echo "Downloading $OUTPUT_NAME ..."
  wget --load-cookies /tmp/cookies.txt \
    "https://docs.google.com/uc?export=download&confirm=$(wget --quiet \
      --save-cookies /tmp/cookies.txt --keep-session-cookies --no-check-certificate \
      "https://docs.google.com/uc?export=download&id=${FILE_ID}" -O- | \
      sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\1/p')&id=${FILE_ID}" \
    -O "${OUTPUT_NAME}" && rm -f /tmp/cookies.txt
}

echo "Going to /tmp"
cd /tmp || exit 1

echo "Cleaning up to get some extra space"
rm -rf /var/log/* /alarm*

echo "Downloading new firmware from Google Drive"
download_from_gdrive "${KERNEL_ID}" "${KERNEL}"
download_from_gdrive "${ROOTFS_ID}" "${ROOTFS}"

echo "Creating fw_env for uboot-envtools"
echo "/dev/mtd12 0x0000 0x10000 0x10000" > /etc/fw_env.config

echo "Setting primaryboot to partA"
echo 0 > /proc/boot_info/rootfs/primaryboot
mtd write /proc/boot_info/getbinary_bootconfig /dev/mtd5
mtd write /proc/boot_info/getbinary_bootconfig /dev/mtd10

echo "Disabling partB"
fw_setenv partAversion OpenWRT
fw_setenv partBversion Wi-Fi16A_AP.xx.xx.xx
# mtd erase /dev/mtd1  # uncomment nếu cần

echo "Backing up MAC, SN to u-boot env"
fw_setenv ethaddr "$(cat /proc/eidData/MACAddress | sed -E 's/([0-9A-Fa-f]{2})/\1:/g; s/:$//')"
fw_setenv serialnumber "$(cat /proc/eidData/SerialNumber)"

echo "Detaching UBI"
ubidetach -p /dev/mtd0 -f 2>/dev/null
ubidetach -p /dev/mtd1 -f 2>/dev/null

echo "Creating new UBI in partA"
ubiformat /dev/mtd0 -y
ubiattach -p /dev/mtd0 

echo "Creating new UBI volumes"
ubimkvol /dev/ubi0 -s "$(wc -c < "${KERNEL}")" -N kernel
ubimkvol /dev/ubi0 -s "$(wc -c < "${ROOTFS}")" -N ubi_rootfs
ubimkvol /dev/ubi0 -m -N rootfs_data

echo "Writing image..."
ubiupdatevol /dev/ubi0_0 "${KERNEL}"
ubiupdatevol /dev/ubi0_1 "${ROOTFS}"

echo "Done. System will reboot NOW!"
sleep 2
echo b > /proc/sysrq-trigger

