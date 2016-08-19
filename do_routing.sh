#!/bin/bash
. network.conf

stop(){
ip route flush table $routing_table1
ip route flush table $routing_table2

ip rule del from $isp1_ip table $routing_table1
ip rule del from $isp2_ip table $routing_table2
ip rule del fwmark 251 table $routing_table2
sysctl -w net.ipv4.ip_forward=0
echo 1 > /proc/sys/net/ipv4/conf/all/rp_filter
iptables -t nat -F POSTROUTING
iptables -t mangle -F PREROUTING
}

start(){
ip route add $isp1_network dev $isp1_interface src $isp1_ip table $routing_table1
ip route add default via $isp1_gw table $routing_table1
ip route add $isp2_network dev $isp2_interface src $isp2_ip table $routing_table2
ip route add default via $isp2_gw table $routing_table2



ip rule add from $isp1_ip table $routing_table1 
ip rule add from $isp2_ip table $routing_table2 
ip rule add fwmark 251 table $routing_table2 

sysctl -w net.ipv4.ip_forward=1
echo 0 > /proc/sys/net/ipv4/conf/all/rp_filter

iptables -t nat -A POSTROUTING -o $isp1_interface -j MASQUERADE
iptables -t nat -A POSTROUTING -o $isp2_interface -j MASQUERADE

iptables -t mangle -A PREROUTING -s $lan_subnet -m conntrack ! --ctstate NEW -m connmark ! --mark 0 -j CONNMARK --restore-mark
iptables -t mangle -A PREROUTING -s $lan_subnet -p tcp --dport 80 -m conntrack --ctstate NEW -m connmark --mark 0 -j MARK --set-mark 251
iptables -t mangle -A PREROUTING -s $lan_subnet -p icmp --icmp-type echo-request -m connmark --mark 0 -j MARK --set-mark 251
iptables -t mangle -A PREROUTING -m conntrack --ctstate NEW -m mark ! --mark 0 -j CONNMARK --save-mark
}
status(){
echo "="
echo "routing table $routing_table1:"
echo "="
ip r s t $routing_table1
echo "="
echo "routing table $routing_table2:"
echo "="
ip r s t $routing_table2
echo "="
ip rule ls
echo "="
echo "="
iptables -t nat -nvL POSTROUTING
echo "="
echo "="
iptables -t mangle -nvL PREROUTING
}

case $1 in
start)   start
         ;;

restart) stop
         start
         ;;
stop)
         stop
         ;;
status)  status
         ;;
   
*)       echo "usage $0 [stop|start|restart]"
         ;;
esac
