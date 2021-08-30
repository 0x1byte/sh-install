echo "Installing dependencies..."
echo ""
read -rp "do you want to install epel?(y/n)" -e yesno

if [[ "$CONTINUE" = "y" ]]; then
    yum update && yum upgrade -y
    yum install epel-release -y
fi
echo "Installing shadowsocks..."
echo ""
yum install -y gcc gettext autoconf libtool automake make pcre-devel asciidoc xmlto udns-devel libev-devel libsodium-devel mbedtls-devel git m2crypto c-ares-devel

cd /opt
git clone https://github.com/shadowsocks/shadowsocks-libev.git
cd shadowsocks-libev
git submodule update --init --recursive

./autogen.sh
./configure
make && make install

adduser --system --no-create-home -s /bin/false shadowsocks

mkdir -m 755 /etc/shadowsocks

read -rp "Enter shadowsocks port: " -e PORT

read -rp "Enter shadowsocks password: " -e PASSWORD

read -rp "Enter shadowsocks nameserver: " -e NAMESERVER

echo "
{
    \"server\":\"0.0.0.0\",
    \"server_port\":$PORT,
    \"password\":\"$PASSWORD\",
    \"timeout\":300,
    \"method\":\"aes-256-gcm\",
    \"nameserver\":\"$NAMESERVER\",
    \"fast_open\": true
}
" >> /etc/shadowsocks/shadowsocks.json

echo '
# max open files
fs.file-max = 51200
# max read buffer
net.core.rmem_max = 67108864
# max write buffer
net.core.wmem_max = 67108864
# default read buffer
net.core.rmem_default = 65536
# default write buffer
net.core.wmem_default = 65536
# max processor input queue
net.core.netdev_max_backlog = 4096
# max backlog
net.core.somaxconn = 4096
# resist SYN flood attacks
net.ipv4.tcp_syncookies = 1
# reuse timewait sockets when safe
net.ipv4.tcp_tw_reuse = 1
# turn off fast timewait sockets recycling
net.ipv4.tcp_tw_recycle = 0
# short FIN timeout
net.ipv4.tcp_fin_timeout = 30
# short keepalive time
net.ipv4.tcp_keepalive_time = 1200
# outbound port range
net.ipv4.ip_local_port_range = 10000 65000
# max SYN backlog
net.ipv4.tcp_max_syn_backlog = 4096
# max timewait sockets held by system simultaneously
net.ipv4.tcp_max_tw_buckets = 5000
# turn on TCP Fast Open on both client and server side
net.ipv4.tcp_fastopen = 3
# TCP receive buffer
net.ipv4.tcp_rmem = 4096 87380 67108864
# TCP write buffer
net.ipv4.tcp_wmem = 4096 65536 67108864
# turn on path MTU discovery
net.ipv4.tcp_mtu_probing = 1
# for high-latency network
net.ipv4.tcp_congestion_control = hybla
# for low-latency network, use cubic instead
net.ipv4.tcp_congestion_control = cubic
' >> /etc/sysctl.d/local.conf

sysctl --system

echo '
[Unit]
Description=Shadowsocks proxy server

[Service]
User=root
Group=root
Type=simple
ExecStart=/usr/local/bin/ss-server -c /etc/shadowsocks/shadowsocks.json -a shadowsocks -v start
ExecStop=/usr/local/bin/ss-server -c /etc/shadowsocks/shadowsocks.json -a shadowsocks -v stop

[Install]
WantedBy=multi-user.target
' >> /etc/systemd/system/shadowsocks.service

systemctl daemon-reload
systemctl enable shadowsocks
systemctl start shadowsocks
