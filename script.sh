#!/bin/bash

##################################### < DEPENDENCIES   > #####################################
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit 1
fi

if ! hash hostapd 2>/dev/null; then
    echo -e "hostapd not found. Installing..."
    echo ""
    apt-get install hostapd -y
fi

if ! hash dnsmasq 2>/dev/null; then
    echo -e "dnsmasq not found. Installing..."
    echo ""
    apt-get install dnsmasq -y
fi

##################################### < CONFIGURATION  > #####################################
# Colors
white="\033[1;37m"
grey="\033[0;37m"
purple="\033[0;35m"
red="\033[1;31m"
green="\033[1;32m"
yellow="\033[1;33m"
Purple="\033[0;35m"
Cyan="\033[0;36m"
Cafe="\033[0;33m"
Fiuscha="\033[0;35m"
blue="\033[1;34m"
transparent="\e[0m"

# Files
WPA_SUPPLICANT_CONFIG_FILE="/etc/wpa_supplicant/wpa_supplicant.conf"
INTERFACES_CONFIG_FILE="/etc/network/interfaces"
HOSTAPD_CONFIG_FILE="/etc/hostapd/hostapd.conf"
HOSTAPD_DEFAULT_CONFIG_FILE="/etc/default/hostapd"
HOSTAPD_START_SCRIPT_FILE="/usr/local/bin/hostapdstart"
DNSMASQ_CONFIG_FILE="/etc/dnsmasq.conf"
STARTUP_CONFIG_FILE="/etc/rc.local"

##################################### <   USER INPUT   > #####################################
read -p 'Insert AP network SSID: ' AP_NETWORK_SSID
read -p 'Insert AP network password: ' AP_NETWORK_PSWD
read -p 'Insert AP network channel: ' AP_NETWORK_CHNL
read -p 'Insert CLIENT network SSID: ' CLIENT_NETWORK_SSID
read -p 'Insert CLIENT network password: ' CLIENT_NETWORK_PSWD
NETWORK_INTERFACE=wlan0 #TODO make it an input and test if interface exists

echo ""

##################################### < WPA_SUPPLICANT > #####################################
echo -e "${yellow}Configuring wpa_supplicant...${transparent}"

if [ -f ${WPA_SUPPLICANT_CONFIG_FILE} ]; then
    if [ ! -f ${WPA_SUPPLICANT_CONFIG_FILE}.bak ]; then
        echo -e "${Cyan}Creating ${WPA_SUPPLICANT_CONFIG_FILE} backup...${transparent}"
        cp ${WPA_SUPPLICANT_CONFIG_FILE}{,.bak}
    fi
    rm -f ${WPA_SUPPLICANT_CONFIG_FILE}
fi

echo -e "${Cyan}Creating new ${WPA_SUPPLICANT_CONFIG_FILE} file...${transparent}"
cat > ${WPA_SUPPLICANT_CONFIG_FILE} << EOL
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

network={
    ssid="${CLIENT_NETWORK_SSID}"
    psk="${CLIENT_NETWORK_PSWD}"
}
EOL

echo -e "${blue}Done!${transparent}"
echo ""

##################################### <   INTERFACES   > #####################################
echo -e "${yellow}Configuring interfaces...${transparent}"

if [ -f ${INTERFACES_CONFIG_FILE} ]; then
    if [ ! -f ${INTERFACES_CONFIG_FILE}.bak ]; then
        echo -e "${Cyan}Creating ${INTERFACES_CONFIG_FILE} backup...${transparent}"
        cp ${INTERFACES_CONFIG_FILE}{,.bak}
    fi
    rm -f ${INTERFACES_CONFIG_FILE}
fi

echo -e "${Cyan}Creating new ${INTERFACES_CONFIG_FILE} file...${transparent}"
cat > ${INTERFACES_CONFIG_FILE} << EOL
source-directory /etc/network/interfaces.d

auto lo
auto eth0
auto ${NETWORK_INTERFACE}
auto uap0

iface eth0 inet dhcp
iface lo inet loopback

allow-hotplug ${NETWORK_INTERFACE}

iface ${NETWORK_INTERFACE} inet dhcp
wpa-conf ${WPA_SUPPLICANT_CONFIG_FILE}

iface uap0 inet static
  address 192.168.50.1
  netmask 255.255.255.0
  network 192.168.50.0
  broadcast 192.168.50.255
  gateway 192.168.50.1
EOL

echo -e "${blue}Done!${transparent}"
echo ""

##################################### <    HOSTAPD     > #####################################
echo -e "${yellow}Configuring hostapd...${transparent}"

if [ -f ${HOSTAPD_CONFIG_FILE} ]; then
    if [ ! -f ${HOSTAPD_CONFIG_FILE}.bak ]; then
        echo -e "${Cyan}Creating ${HOSTAPD_CONFIG_FILE} backup...${transparent}"
        cp ${HOSTAPD_CONFIG_FILE}{,.bak}
    fi
    rm -f ${HOSTAPD_CONFIG_FILE}
fi

echo -e "${Cyan}Creating new ${HOSTAPD_CONFIG_FILE} file...${transparent}"
cat > ${HOSTAPD_CONFIG_FILE} << EOL
interface=uap0
ssid=${AP_NETWORK_SSID}
hw_mode=g
channel=${AP_NETWORK_CHNL}
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=${AP_NETWORK_PSWD}
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
EOL

if [ -f ${HOSTAPD_DEFAULT_CONFIG_FILE} ]; then
    if [ ! -f ${HOSTAPD_DEFAULT_CONFIG_FILE}.bak ]; then
        echo -e "${Cyan}Creating ${HOSTAPD_DEFAULT_CONFIG_FILE} backup...${transparent}"
        cp ${HOSTAPD_DEFAULT_CONFIG_FILE}{,.bak}
    fi
    rm -f ${HOSTAPD_DEFAULT_CONFIG_FILE}
fi

echo -e "${Cyan}Creating new ${HOSTAPD_DEFAULT_CONFIG_FILE} file...${transparent}"
cat > ${HOSTAPD_DEFAULT_CONFIG_FILE} << EOL
DAEMON_OPTS="${HOSTAPD_CONFIG_FILE}"
EOL

echo -e "${blue}Done!${transparent}"
echo ""

##################################### < HOSTAPD START  > #####################################
echo -e "${yellow}Configuring hostapd start script...${transparent}"

if [ -f ${HOSTAPD_START_SCRIPT_FILE} ]; then
    if [ ! -f ${HOSTAPD_START_SCRIPT_FILE}.bak ]; then
        echo "${Cyan}Creating ${HOSTAPD_START_SCRIPT_FILE} backup...${transparent}"
        cp ${HOSTAPD_START_SCRIPT_FILE}{,.bak}
    fi
    rm -f ${HOSTAPD_START_SCRIPT_FILE}
fi

echo -e "${Cyan}Creating new ${HOSTAPD_START_SCRIPT_FILE} file...${transparent}"
cat > ${HOSTAPD_START_SCRIPT_FILE} << EOL
#!/bin/bash

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
iw dev ${NETWORK_INTERFACE} interface add uap0 type __ap
service dnsmasq restart
sysctl net.ipv4.ip_forward=1
iptables -t nat -A POSTROUTING -s 192.168.50.0/24 ! -d 192.168.50.0/24 -j MASQUERADE
ifup uap0
hostapd ${HOSTAPD_CONFIG_FILE}
EOL

chmod 775 ${HOSTAPD_START_SCRIPT_FILE}

echo -e "${blue}Done!${transparent}"
echo ""

##################################### <    DNSMASQ     > #####################################
echo -e "${yellow}Configuring dnsmasq...${transparent}"

if [ -f ${DNSMASQ_CONFIG_FILE} ]; then
    if [ ! -f ${DNSMASQ_CONFIG_FILE}.bak ]; then
        echo -e "${Cyan}Creating ${DNSMASQ_CONFIG_FILE} backup...${transparent}"
        cp ${DNSMASQ_CONFIG_FILE}{,.bak}
    fi
    rm -f ${DNSMASQ_CONFIG_FILE}
fi

echo -e "${Cyan}Creating new ${DNSMASQ_CONFIG_FILE} file...${transparent}"
cat > ${DNSMASQ_CONFIG_FILE} << EOL
interface=lo,uap0
no-dhcp-interface=lo,${NETWORK_INTERFACE}
bind-interfaces
server=8.8.8.8
domain-needed
bogus-priv
dhcp-range=192.168.50.50,192.168.50.150,12h
EOL

echo -e "${green}Starting dnmasq service...${transparent}"
service dnsmasq start

##################################### <    STARTUP     > #####################################
echo -e "${yellow}Configuring startup script...${transparent}"

if [ -f ${STARTUP_CONFIG_FILE} ]; then
    if [ ! -f ${STARTUP_CONFIG_FILE}.bak ]; then
        echo -e "${Cyan}Creating ${STARTUP_CONFIG_FILE} backup...${transparent}"
        cp ${STARTUP_CONFIG_FILE}{,.bak}
    fi
    rm -f ${STARTUP_CONFIG_FILE}
fi

echo -e "${Cyan}Creating new ${STARTUP_CONFIG_FILE} file...${transparent}"
cat > ${STARTUP_CONFIG_FILE} << EOL
#!/bin/sh -e

_IP=\$(hostname -I) || true
if [ "\$_IP" ]; then
  printf "My IP address is %s\n" "\$_IP"
fi

/bin/bash ${HOSTAPD_START_SCRIPT_FILE}

exit 0
EOL

echo -e "${blue}Done!${transparent}"
echo ""

##################################### <     REBOOT     > #####################################
while true; do
    read -p "Your system needs to be restarted to finish then installation. Do you want to restart now? " yn
    case $yn in
        [Yy]* ) reboot; break;;
        [Nn]* ) exit;;
        * ) exit;;
    esac
done
