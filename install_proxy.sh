# Install squid proxy
export DEBIAN_FRONTEND=noninteractive
apt-get -yy install kubectl 
apt-get -yy install google-cloud-sdk-gke-gcloud-auth-plugin
apt-get -yy update
apt-get -yy install squid
cat << EOF > /etc/squid/squid.conf
acl localnet src 10.0.0.0/8
acl localnet src fc00::/7
acl localnet src fe80::/10
acl to_metadata dst 169.254.169.254

acl SSL_ports port 443
acl Safe_ports port 80
acl Safe_ports port 443
acl CONNECT method CONNECT

http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports
http_access deny to_metadata
http_access allow localhost manager
http_access deny manager

include /etc/squid/conf.d/*

http_access allow all
#http_access allow local
#http_access deny all
http_port 3128
visible_hostname proxy.example.internal

access_log none
EOF

systemctl enable squid.service
systemctl restart squid.service
