#!/bin/bash
colorized_echo() {
    local color=$1
    local text=$2
    
    case $color in
        "red")
        printf "\e[91m${text}\e[0m\n";;
        "green")
        printf "\e[92m${text}\e[0m\n";;
        "yellow")
        printf "\e[93m${text}\e[0m\n";;
        "blue")
        printf "\e[94m${text}\e[0m\n";;
        "magenta")
        printf "\e[95m${text}\e[0m\n";;
        "cyan")
        printf "\e[96m${text}\e[0m\n";;
        *)
            echo "${text}"
        ;;
    esac
}

# Check if the script is run as root
if [ "$(id -u)" != "0" ]; then
    colorized_echo red "Error: Skrip ini harus dijalankan sebagai root."
    exit 1
fi

# Check supported operating system before changing packages
supported_os=false
os_name=""
os_version=""

if [ -r /etc/os-release ]; then
    . /etc/os-release
    os_name="${ID:-}"
    os_version="${VERSION_ID:-}"

    if [ "$os_name" = "debian" ] && [[ "$os_version" =~ ^(11|12)$ ]]; then
        supported_os=true
    elif [ "$os_name" = "ubuntu" ] && [[ "$os_version" =~ ^(20\.04|22\.04|24\.04)$ ]]; then
        supported_os=true
    fi
fi

if [ "$supported_os" != true ]; then
    colorized_echo red "Error: Skrip ini hanya support di Debian 11/12 dan Ubuntu 20.04/22.04/24.04. OS terdeteksi: ${os_name:-unknown} ${os_version:-unknown}"
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y sudo curl ca-certificates

mkdir -p /etc/data

#domain
read -rp "Masukkan Domain: " domain
echo "$domain" > /etc/data/domain
domain=$(cat /etc/data/domain)

#email
read -rp "Masukkan Email anda: " email

#username
while true; do
    read -rp "Masukkan UsernamePanel (hanya huruf dan angka): " userpanel

    # Memeriksa apakah userpanel hanya mengandung huruf dan angka
    if [[ ! "$userpanel" =~ ^[A-Za-z0-9]+$ ]]; then
        echo "UsernamePanel hanya boleh berisi huruf dan angka. Silakan masukkan kembali."
    elif [[ "$userpanel" =~ [Aa][Dd][Mm][Ii][Nn] ]]; then
        echo "UsernamePanel tidak boleh mengandung kata 'admin'. Silakan masukkan kembali."
    else
        echo "$userpanel" > /etc/data/userpanel
        break
    fi
done

read -rp "Masukkan Password Panel: " passpanel
echo "$passpanel" > /etc/data/passpanel

#Preparation
clear
cd;
apt-get update;

#Remove unused Module
apt-get -y --purge remove samba*;
apt-get -y --purge remove apache2*;
apt-get -y --purge remove sendmail*;
apt-get -y --purge remove bind9*;

#install bbr
echo 'fs.file-max = 500000
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.netdev_max_backlog = 250000
net.core.somaxconn = 4096
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.ip_local_port_range = 10000 65000
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mem = 25600 51200 102400
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.core.rmem_max = 4000000
net.ipv4.tcp_mtu_probing = 1
net.ipv4.ip_forward = 1
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1' >> /etc/sysctl.conf
sysctl -p;

#install toolkit
apt-get install -y libio-socket-inet6-perl libsocket6-perl libcrypt-ssleay-perl libnet-libidn-perl perl libio-socket-ssl-perl libwww-perl libpcre3 libpcre3-dev zlib1g-dev dbus iftop zip unzip wget net-tools curl nano sed screen gnupg bc build-essential dirmngr dnsutils sudo at htop iptables bsdmainutils cron lsof lnav

#Set Timezone GMT+7
timedatectl set-timezone Asia/Jakarta;

#Install Marzban
sudo bash -c "$(curl -sL https://github.com/GawrAme/Marzban-scripts/raw/master/marzban.sh)" @ install

#Install Subs
wget -N -P /var/lib/marzban/templates/subscription/  https://raw.githubusercontent.com/GawrAme/MarLing/main/index.html

#install env
wget -O /opt/marzban/.env "https://raw.githubusercontent.com/GawrAme/MarLing/main/env"

#install Assets folder
mkdir -p /var/lib/marzban/assets
cd

#profile
echo -e 'profile' >> /root/.profile
wget -O /usr/bin/profile "https://raw.githubusercontent.com/GawrAme/MarLing/main/profile";
chmod +x /usr/bin/profile
# neofetch is unavailable in some Ubuntu 24.04 mirrors; use fastfetch or a no-op fallback.
if apt-cache show neofetch >/dev/null 2>&1; then
    apt-get install -y neofetch
elif apt-cache show fastfetch >/dev/null 2>&1; then
    apt-get install -y fastfetch
    ln -sf /usr/bin/fastfetch /usr/local/bin/neofetch
else
    printf '#!/bin/sh\nexit 0\n' > /usr/local/bin/neofetch
    chmod 755 /usr/local/bin/neofetch
fi
wget -O /usr/bin/cekservice "https://raw.githubusercontent.com/GawrAme/MarLing/main/cekservice.sh"
chmod +x /usr/bin/cekservice

#install compose
wget -O /opt/marzban/docker-compose.yml "https://raw.githubusercontent.com/GawrAme/MarLing/main/docker-compose.yml"

# Install the distro vnstat package. Building the legacy 2.6 tarball breaks on
# newer Ubuntu toolchains and is unnecessary because Ubuntu 24.04 ships vnstat.
apt-get install -y vnstat
mkdir -p /var/lib/vnstat
if id vnstat >/dev/null 2>&1; then
    chown -R vnstat:vnstat /var/lib/vnstat
fi
systemctl enable --now vnstat

#Install Speedtest
curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | sudo bash
sudo apt-get install speedtest -y

#install nginx
mkdir -p /var/log/nginx
touch /var/log/nginx/access.log
touch /var/log/nginx/error.log
wget -O /opt/marzban/nginx.conf "https://raw.githubusercontent.com/GawrAme/MarLing/main/nginx.conf"
wget -O /opt/marzban/default.conf "https://raw.githubusercontent.com/GawrAme/MarLing/main/vps.conf"
wget -O /opt/marzban/xray.conf "https://raw.githubusercontent.com/GawrAme/MarLing/main/xray.conf"
mkdir -p /var/www/html
wget -qO /var/www/html/index.html "https://raw.githubusercontent.com/rdk-i/Marcok/main/landing.html"
wget -qO /var/www/html/marcok-login.css "https://raw.githubusercontent.com/rdk-i/Marcok/main/marcok-login.css"
chmod 644 /var/www/html/index.html /var/www/html/marcok-login.css

#install socat
apt install iptables -y
apt-get install -y curl socat xz-utils wget gnupg gnupg2 dnsutils lsb-release
apt install socat cron bash-completion -y

#install cert
curl https://get.acme.sh | sh -s email=$email
/root/.acme.sh/acme.sh --server letsencrypt --register-account -m $email --issue -d $domain --standalone -k ec-256 --debug
~/.acme.sh/acme.sh --installcert -d $domain --fullchainpath /var/lib/marzban/xray.crt --keypath /var/lib/marzban/xray.key --ecc
wget -O /var/lib/marzban/xray_config.json "https://raw.githubusercontent.com/GawrAme/MarLing/main/xray_config.json"

#install firewall
apt install ufw -y
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow https
sudo ufw allow 8081/tcp
sudo ufw allow 1080/tcp
sudo ufw allow 1080/udp
yes | sudo ufw enable

#install database
wget -O /var/lib/marzban/db.sqlite3 "https://github.com/GawrAme/MarLing/raw/main/db.sqlite3"

#install WARP Proxy
wget -O /root/warp "https://raw.githubusercontent.com/hamid-gh98/x-ui-scripts/main/install_warp_proxy.sh"
sudo chmod +x /root/warp
sudo bash /root/warp -y 

#finishing
apt autoremove -y
apt clean
cd /opt/marzban
sed -i "s/# SUDO_USERNAME = \"admin\"/SUDO_USERNAME = \"${userpanel}\"/" /opt/marzban/.env
sed -i "s/# SUDO_PASSWORD = \"admin\"/SUDO_PASSWORD = \"${passpanel}\"/" /opt/marzban/.env
docker compose down && docker compose up -d
marzban cli admin import-from-env -y
sed -i "s/SUDO_USERNAME = \"${userpanel}\"/# SUDO_USERNAME = \"admin\"/" /opt/marzban/.env
sed -i "s/SUDO_PASSWORD = \"${passpanel}\"/# SUDO_PASSWORD = \"admin\"/" /opt/marzban/.env
docker compose down && docker compose up -d
cd
echo "Tunggu 30 detik untuk generate token API"
sleep 30s

#instal token
curl -X 'POST' \
  "https://${domain}/api/admin/token" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d "grant_type=password&username=${userpanel}&password=${passpanel}&scope=&client_id=string&client_secret=string" > /etc/data/token.json
cd
touch /root/log-install.txt
echo -e "Untuk data login dashboard Marzban: 
-=================================-
URL HTTPS : https://${domain}/dashboard 
username  : ${userpanel}
password  : ${passpanel}
-=================================-
Jangan lupa join Channel & Grup Telegram saya juga di
Telegram Channel: https://t.me/LingVPN
Telegram Group: https://t.me/LingVPN_Group
-=================================-" > /root/log-install.txt
profile
colorized_echo green "Script telah berhasil di install"
rm /root/mar.sh
colorized_echo blue "Menghapus admin bawaan db.sqlite"
marzban cli admin delete -u admin -y
echo -e "[\e[1;31mWARNING\e[0m] Reboot sekali biar ga error lur [default y](y/n)? "
read answer
if [ "$answer" == "${answer#[Yy]}" ] ;then
exit 0
else
cat /dev/null > ~/.bash_history && history -c && reboot
fi
