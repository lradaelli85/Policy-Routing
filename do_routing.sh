#!/bin/bash
. network.conf

ip route add $isp1_network dev $isp1_interface src $isp1_ip table isp1
ip route add default via $isp1_gw table isp1
ip route add $isp2_network dev $isp2_interface src $isp2_ip table isp2
ip route add default via $isp2_gw table isp2


ip rule add from $isp1_ip table isp1
ip rule add from $isp2_ip table isp2
ip rule add fwmark 251 table isp2

sysctl -w net.ipv4.ip_forward=1
echo 0 > /proc/sys/net/ipv4/conf/all/rp_filter

iptables -t nat -A POSTROUTING -o $isp2_interface -j MASQUERADE
iptables -t nat -A POSTROUTING -o $isp1_interface -j MASQUERADE

iptables -t mangle -A PREROUTING -s $lan_subnet -m conntrack ! --ctstate NEW -m connmark ! --mark 0 -j CONNMARK --restore-mark
iptables -t mangle -A PREROUTING -s $lan_subnet -p tcp --dport 80 -m conntrack --ctstate NEW -m connmark --mark 0 -j MARK --set-mark 251
iptables -t mangle -A PREROUTING -s $lan_subnet -p icmp --icmp-type echo-request -m connmark --mark 0 -j MARK --set-mark 251
iptables -t mangle -A PREROUTING -m conntrack --ctstate NEW -m mark ! --mark 0 -j CONNMARK --save-mark
