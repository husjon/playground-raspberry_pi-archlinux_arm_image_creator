#!/bin/bash

press_any_key() {
    read -n 1
}
sleep_or_wait_for_keypress() {
    [[ $DEBUG ]] && echo "Press any key to continue..." && press_any_key || sleep 1
}

TMP_DIR=/tmp/arch_pi

if [[ ! "/dev" =~ "$1*" ]] && [ ! -b "$1" ]; then
    echo "Needs a valid device (ex: /dev/sda)"
    exit
fi

TGTDEV="$1"
echo "Setting up partition..."
(
   echo 'o';    # clear the in memory partition table
   echo 'p';    # list existing partitions

   echo 'n';    # new partition
   echo 'p';    # primary partition
   echo '1';    # partition number 1
   echo '';     # default - start at beginning of disk
   echo '+100M';# 100 MB boot parttion

   echo 't';    # partition type
   echo 'c';    # W95 FAT32
   sleep 1

   echo 'n';    # new partition
   echo 'p';    # primary partition
   echo '2';    # partion number 2
   echo '';     # default, start immediately after preceding partition
   echo '';     # default, extend partition to end of disk

   sleep 1
   echo 'w';    # write the partition table
) | fdisk ${TGTDEV} || exit 1
sleep_or_wait_for_keypress


echo "Partprobe..."
partprobe -s ${TGTDEV}
sleep_or_wait_for_keypress

echo "mkfs..."
mkfs.vfat ${TGTDEV}1
mkfs.ext4 -F ${TGTDEV}2
sleep_or_wait_for_keypress

echo "Setting up environment..."
mkdir -p ${TMP_DIR}/root
mount ${TGTDEV}2 ${TMP_DIR}/root

mkdir -p ${TMP_DIR}/root/boot
mount ${TGTDEV}1 ${TMP_DIR}/root/boot

cd ${TMP_DIR}
sleep_or_wait_for_keypress


echo "Checking for ArchLinuxARM archive..."
[ ! -f "${TMP_DIR}/ArchLinuxARM-rpi-2-latest.tar.gz" ] && \
    echo "Archive missing, fetching: ArchLinuxARM-rpi-2-latest.tar.gz" && \
    wget -q http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-2-latest.tar.gz \
        -O "${TMP_DIR}/ArchLinuxARM-rpi-2-latest.tar.gz"
sleep_or_wait_for_keypress

echo "Extracting..."
bsdtar -xpf "${TMP_DIR}/ArchLinuxARM-rpi-2-latest.tar.gz" -C ${TMP_DIR}/root
sleep_or_wait_for_keypress

echo "Syncing..."
time sync
sleep_or_wait_for_keypress

echo "Copying SSH key"
mkdir -p root/root/.ssh
cat /home/$SUDO_USER/.ssh/id_rsa.pub > root/root/.ssh/authorized_keys
sleep_or_wait_for_keypress

echo "Setting up /etc/shadow"
cat << EOF > root/etc/shadow
root::17775::::::
bin:!!:17775::::::
daemon:!!:17775::::::
mail:!!:17775::::::
ftp:!!:17775::::::
http:!!:17775::::::
nobody:!!:17775::::::
dbus:!!:17775::::::
systemd-journal-remote:!!:17775::::::
systemd-coredump:!!:17775::::::
uuidd:!!:17775::::::
alarm::17775:0:99999:7:::
EOF
sleep_or_wait_for_keypress

echo "Setting up systemd service for pacman init..."
cp ./pacman_keyinit.service ln ${TMP_DIR}/root/etc/systemd/system/pacman_keyinit.service
ln -rs /etc/systemd/system/pacman_keyinit.service ${TMP_DIR}/root/etc/systemd/system/multi-user.target.wants/pacman_keyinit.service
sleep_or_wait_for_keypress

echo "Unmounting"
umount ${TMP_DIR}/{boot,root}
sleep_or_wait_for_keypress

echo "Done."
notify-send -u critical "Finished writing $1"
