#!/bin/sh

# Firewall everything has to go through the vpn
iptables  -F OUTPUT
ip6tables -F OUTPUT 2> /dev/null
iptables  -P OUTPUT DROP
ip6tables -P OUTPUT DROP 2> /dev/null
iptables  -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 
ip6tables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2> /dev/null
iptables  -A OUTPUT -o lo -j ACCEPT
ip6tables -A OUTPUT -o lo -j ACCEPT 2> /dev/null
iptables  -A OUTPUT -o tun0 -j ACCEPT 
ip6tables -A OUTPUT -o tun0 -j ACCEPT 2> /dev/null
iptables  -A OUTPUT -d `ip -o addr show dev eth0 | awk '$3 == "inet" {print $4}'` -j ACCEPT
ip6tables -A OUTPUT -d `ip -o addr show dev eth0 | awk '$3 == "inet6" {print $4; exit}'` -j ACCEPT 2> /dev/null
iptables  -A OUTPUT -p udp --dport 53 -j ACCEPT
ip6tables -A OUTPUT -p udp --dport 53 -j ACCEPT 2> /dev/null
iptables  -A OUTPUT -o eth0 -p udp --dport 1194 -j ACCEPT 
ip6tables -A OUTPUT -o eth0 -p udp --dport 1194 -j ACCEPT 2> /dev/null
iptables  -A OUTPUT -o eth0 -p tcp --dport 1194 -j ACCEPT 
ip6tables -A OUTPUT -o eth0 -p tcp --dport 1194 -j ACCEPT 2> /dev/null
iptables  -A OUTPUT -o eth0 -d nordvpn.com -j ACCEPT
ip6tables -A OUTPUT -o eth0 -d nordvpn.com -j ACCEPT 2> /dev/null

if [ ! -z $NETWORK ]; then
    gw=`ip route | awk '/default/ {print $3}'`
    ip route add to $NETWORK via $gw dev eth0
    iptables -A OUTPUT --destination $NETWORK -j ACCEPT
fi

if [ ! -z $NETWORK6 ]; then
    gw=`ip -6 route | awk '/default/ {print $3}'`
    ip -6 route add to $NETWORK6 via $gw dev eth0
    ip6tables -A OUTPUT --destination $NETWORK6 -j ACCEPT 2> /dev/null
fi

base_dir="/vpn"
ovpn_dir="$base_dir/ovpn"
auth_file="$base_dir/auth"

# Get NordVpn server recomendations
recomendations=`curl -s https://nordvpn.com/wp-admin/admin-ajax.php?action=servers_recommendations |\
                jq -r '.[] | .hostname' | shuf`

for recomendation in ${recomendations}; do # Prefer UDP
    config_file="${ovpn_dir}/${recomendation}.udp.ovpn"
    if [ -r "$config_file" ]; then
        config="$config_file"
        break
    fi
done
if [ -z $config ]; then # Use TCP if UDP not available
   for recomendation in ${recomendations}; do
        config_file="${ovpn_dir}/${recomendation}.tcp.ovpn"
        if [ -r "$config_file" ]; then
            config="$config_file"
            break
        fi
    done
fi
if [ -z $config ]; then # If recomendation was not found, use a random server
    config="${ovpn_dir}/`ls ${ovpn_dir} | shuf -n 1`"
fi

# Create auth_file
echo "$USER" > $auth_file 
echo "$PASS" >> $auth_file
chmod 0600 $auth_file

openvpn --cd $base_dir --config $config \
    --auth-user-pass $auth_file --auth-nocache \
    --script-security 2 --up /etc/openvpn/up.sh --down /etc/openvpn/down.sh