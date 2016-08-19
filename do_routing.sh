#!/bin/bash
. network.conf
add_local(){
if [ $local_routing -eq 1 ]
then
ip rule add fwmark 250 table $routing_table2  prio 199
iptables -t mangle -N LOCAL_ROUTING
iptables -t mangle -A OUTPUT -p tcp --dport 80 -j LOCAL_ROUTING
iptables -t mangle -A OUTPUT -p icmp --icmp-type 8 -j LOCAL_ROUTING
iptables -t mangle -A LOCAL_ROUTING -m conntrack ! --ctstate NEW -m connmark ! --mark 0 -j CONNMARK --restore-mark
iptables -t mangle -A LOCAL_ROUTING -m conntrack --ctstate NEW -m mark --mark 0 -j MARK --set-mark 250
iptables -t mangle -A LOCAL_ROUTING -m conntrack --ctstate NEW -m mark ! --mark 0 -j CONNMARK --save-mark
fi
}

del_local(){
if [ $local_routing -eq 1 ]
then
ip rule del fwmark 250 table $routing_table2  prio 199
iptables -t mangle -F OUTPUT
iptables -t mangle -F LOCAL_ROUTING
iptables -t mangle -X LOCAL_ROUTING
fi
}
stop(){

ip route flush table $routing_table1
ip route flush table $routing_table2

ip rule del from all to $lan_subnet table main
ip rule del from $isp1_ip table $routing_table1
ip rule del from $isp2_ip table $routing_table2
ip rule del fwmark 251 table $routing_table2
sysctl -w net.ipv4.ip_forward=0
echo 1 > /proc/sys/net/ipv4/conf/all/rp_filter
iptables -t nat -F POSTROUTING
iptables -t mangle -F PREROUTING
del_local

iptables -t mangle -F ROUTING
iptables -t mangle -X ROUTING
}

start(){
iptables -t mangle -N ROUTING
iptables -t mangle -A PREROUTING -j ROUTING
ip route add $isp1_network dev $isp1_interface src $isp1_ip table $routing_table1
ip route add default via $isp1_gw table $routing_table1
ip route add $isp2_network dev $isp2_interface src $isp2_ip table $routing_table2
ip route add default via $isp2_gw table $routing_table2


ip rule add from all to $lan_subnet table main prio 198
ip rule add from $isp1_ip table $routing_table1 prio 200 
ip rule add from $isp2_ip table $routing_table2 prio 200
ip rule add fwmark 251 table $routing_table2  prio 199

sysctl -w net.ipv4.ip_forward=1
echo 0 > /proc/sys/net/ipv4/conf/all/rp_filter

iptables -t nat -A POSTROUTING -o $isp1_interface -j MASQUERADE
iptables -t nat -A POSTROUTING -o $isp2_interface -j MASQUERADE
add_local
iptables -t mangle -A ROUTING -m conntrack --ctstate NEW -i $isp1_interface -j RETURN
iptables -t mangle -A ROUTING -m conntrack --ctstate NEW -i $isp2_interface -j RETURN
iptables -t mangle -A ROUTING -m conntrack ! --ctstate NEW -m connmark --mark 250 -j RETURN
iptables -t mangle -A ROUTING -m conntrack ! --ctstate NEW -m connmark ! --mark 0  -j CONNMARK --restore-mark
iptables -t mangle -A ROUTING -s $lan_subnet -p tcp --dport 80 -m conntrack --ctstate NEW -m connmark --mark 0 -j MARK --set-mark 251
iptables -t mangle -A ROUTING -p icmp --icmp-type echo-request -m connmark --mark 0 -j MARK --set-mark 251
iptables -t mangle -A ROUTING -m conntrack --ctstate NEW -m mark ! --mark 0 -j CONNMARK --save-mark

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
iptables -t mangle -nvL 
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
