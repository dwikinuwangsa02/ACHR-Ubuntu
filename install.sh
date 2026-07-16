#!/usr/bin/env bash

# Function to check for root access
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "\e[31mThis script must be run as root\e[0m" # Red color
        exit 1
    fi
}

# Function to display system details
show_system_details() {
    echo -e "\e[34mGathering system details...\e[0m" # Blue color
    IP=$(curl -s http://checkip.amazonaws.com)
    RAM=$(free -m | awk '/Mem:/ { print $2 }')
    CPU=$(lscpu | grep 'Model name' | cut -d: -f2 | xargs)
    STORAGE=$(df -h | awk '$NF=="/"{printf "%s", $2}')
    echo -e "\e[32mSystem Details:\nIP: $IP\nRAM: ${RAM}MB\nCPU: $CPU\nStorage: $STORAGE\e[0m" # Green color
}

# ASCII Banner
echo -e "\e[33m   _____   _    _   _____                         _           \e[0m"
echo -e "\e[33m  / ____| | |  | | |  __ \        /\             | |          \e[0m"
echo -e "\e[33m | |      | |__| | | |__) |      /  \     _   _  | |_    ___  \e[0m"
echo -e "\e[33m | |      |  __  | |  _  /      / /\ \   | | | | | __|  / _ \ \e[0m"
echo -e "\e[33m | |____  | |  | | | | \ \     / ____ \  | |_| | | |_  | (_) |\e[0m"
echo -e "\e[33m  \_____| |_|  |_| |_|  \_\   /_/    \_\  \__,_|  \__|  \___/ \e[0m"
echo -e "\e[33m                                                              \e[0m"
echo -e "\e[33m                            === By Mostech ===                 \e[0m"


# Check if the user is root
check_root

# Show system details
show_system_details

echo -e "\e[34m[1/5] Preparation: Installing unzip...\e[0m" # Blue color
apt install unzip -y

# Latest Stable
CHR_VERSION=7.21.5

# Environment
DISK=$(lsblk | grep "disk" | head -n 1 | cut -d' ' -f1)
INTERFACE=$(ip -o -4 route show to default | awk '{print $5}')
INTERFACE_IP=$(ip addr show $INTERFACE | grep global | cut -d' ' -f 6 | head -n 1)
INTERFACE_GATEWAY=$(ip route show | grep default | awk '{print $3}')

echo -e "\e[34m[2/5] Downloading and extracting MikroTik CHR v$CHR_VERSION...\e[0m" # Blue color
wget -O routeros.zip https://download.mikrotik.com/routeros/$CHR_VERSION/chr-$CHR_VERSION.img.zip
unzip routeros.zip
rm -rf routeros.zip

echo -e "\e[34m[3/5] Mapping image partitions and configuring IP...\e[0m" # Blue color
# Membuat loop device dan memetakan partisi secara otomatis
LOOP_DEV=$(losetup -fP --show chr-$CHR_VERSION.img)

# Mencoba mount partisi 1
mount ${LOOP_DEV}p1 /mnt 2>/dev/null
# Jika folder /rw tidak ada, coba mount partisi 2
if [ ! -d /mnt/rw ]; then
    umount /mnt 2>/dev/null
    mount ${LOOP_DEV}p2 /mnt 2>/dev/null
fi

# Cek apakah folder /rw berhasil ditemukan
if [ -d /mnt/rw ]; then
    echo "/ip address add address=${INTERFACE_IP} interface=[/interface ethernet find where name=ether1]
/ip route add gateway=${INTERFACE_GATEWAY}
" > /mnt/rw/autorun.scr
    echo -e "\e[32mAutorun script created successfully.\e[0m"
else
    echo -e "\e[33mWarning: Could not find /rw directory. Skipping autorun script injection.\e[0m"
    echo -e "\e[33mYou may need to configure the IP address manually via VNC/Console after reboot.\e[0m"
fi

echo -e "\e[34m[4/5] Unmounting image...\e[0m" # Blue color
umount /mnt 2>/dev/null
losetup -d $LOOP_DEV 2>/dev/null
echo u > /proc/sysrq-trigger

echo -e "\e[34m[5/5] Writing image to disk /dev/${DISK}...\e[0m" # Blue color
dd if=chr-$CHR_VERSION.img of=/dev/${DISK} bs=1M status=progress

echo -e "\e[32m========================================================================\e[0m"
echo -e "\e[32mInstallation complete. Reboot your server now.\e[0m"
echo -e "\e[32mPlease log in and configure your password using Winbox or SSH.\e[0m" 
echo -e "\e[32m========================================================================\e[0m"
