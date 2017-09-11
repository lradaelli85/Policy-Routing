#!/bin/bash
#LOCAL MARK 250
#ISP1 MARK 251
#ISP2 MARK 252

. network.conf

flush_routing_tables(){
#isp1
ip route flush table $gw1_routing_table
ip rule del from $gw1_interface_ip table $gw1_routing_table
ip rule del fwmark $gw1_mark table $gw1_routing_table
#isp2
ip rule del from $gw2_interface_ip table $gw2_routing_table
ip route flush table $gw2_routing_table
ip rule del fwmark $gw2_mark table $gw2_routing_table
#lookup in main table when destination is local
ip rule del to $lan_subnet lookup main


}

add_routing_rules(){
#isp1
ip route add $gw1_network dev $gw1_interface src $gw1_interface_ip table $gw1_routing_table
ip route add default via $gw1_next_hop_ip table $gw1_routing_table
ip rule add from $gw1_interface_ip table $gw1_routing_table prio 200
#isp2
ip route add $gw2_network dev $gw2_interface src $gw2_interface_ip table $gw2_routing_table
ip route add default via $gw2_next_hop_ip table $gw2_routing_table
ip rule add from $gw2_interface_ip table $gw2_routing_table prio 200
#route through isp1 traffic marked with 251
ip rule add fwmark $gw1_mark table $gw1_routing_table prio 199
#route through isp2 traffic marked with 252
ip rule add fwmark $gw2_mark table $gw2_routing_table prio 199
#lookup in main table when destination is local
ip rule add to $lan_subnet lookup main prio 10

}

disable_kernel_parameters(){
#disable forwarding
if [ $forwarding_enabled -eq 1 ]
        then
            sysctl -w net.ipv4.ip_forward=0
fi
#enable reverse path filter
echo 1 > /proc/sys/net/ipv4/conf/all/rp_filter
}

enable_kernel_parameters(){
#enable forwarding
if [ $forwarding_enabled -eq 1 ]
        then
            sysctl -w net.ipv4.ip_forward=1
fi
#disable reverse path filter
echo 0 > /proc/sys/net/ipv4/conf/all/rp_filter
}


add_local_iptables_rules(){
if [ $local_routing -eq 1 ]
        then
            iptables -t mangle -N LOCAL_ROUTING
            #iptables -t mangle -A LOCAL_ROUTING -m conntrack ! --ctstate NEW -m connmark ! --mark 0 -j CONNMARK --restore-mark
            user_rules LOCAL_ROUTING
            #iptables -t mangle -A LOCAL_ROUTING -m conntrack --ctstate NEW -m mark ! --mark 0 -j CONNMARK --save-mark
            iptables -t mangle -A OUTPUT -j LOCAL_ROUTING
fi
}

del_local_iptables_rules(){
if [ $local_routing -eq 1 ]
        then
            iptables -t mangle -D OUTPUT -j LOCAL_ROUTING
            iptables -t mangle -F LOCAL_ROUTING
            iptables -t mangle -X LOCAL_ROUTING
fi
}

add_nat(){
if [ $nat_enabled -eq  1 ]
    then
        iptables -t nat -A POSTROUTING -o $gw1_interface -j MASQUERADE
        iptables -t nat -A POSTROUTING -o $gw2_interface -j MASQUERADE
fi
}

add_iptables_rules(){
iptables -t mangle -N ROUTING
iptables -t mangle -A PREROUTING -m conntrack ! --ctstate NEW -m connmark ! --mark 0  -j CONNMARK --restore-mark
iptables -t mangle -A PREROUTING -j ROUTING
user_rules ROUTING
iptables -t mangle -A POSTROUTING -m conntrack --ctstate NEW -m mark ! --mark 0 -j CONNMARK --save-mark
}

del_iptables_rules(){
if [ $nat_enabled -eq  1 ]
    then
        iptables -t nat -D POSTROUTING -o $gw1_interface -j MASQUERADE
        iptables -t nat -D POSTROUTING -o $gw2_interface -j MASQUERADE
fi
iptables -t mangle -D PREROUTING -m conntrack ! --ctstate NEW -m connmark ! --mark 0  -j CONNMARK --restore-mark
iptables -t mangle -D PREROUTING -j ROUTING
iptables -t mangle -F ROUTING
iptables -t mangle -X ROUTING
iptables -t mangle -D POSTROUTING -m conntrack --ctstate NEW -m mark ! --mark 0 -j CONNMARK --save-mark

}

user_rules(){
./routing_rule.py $1
}

stop(){
del_local_iptables_rules
flush_routing_tables
del_iptables_rules
disable_kernel_parameters
}

start(){
#echo "start add_local_iptables_rules"
add_local_iptables_rules
#echo "start add nat"
add_nat
#echo "start kernel"
enable_kernel_parameters
#echo "start iptables"
add_iptables_rules
#echo "start routing"
add_routing_rules
}

Who_Am_I(){
if [ `id -u` -ne 0 ]
    then
        echo "need root privileges"
        exit 1;
fi
}

status(){
echo "="
echo "routing table $gw1_routing_table:"
echo "="
ip r s t $gw1_routing_table
echo "="
echo "routing table $gw2_routing_table:"
echo "="
ip r s t $gw2_routing_table
echo "="
ip rule ls
echo "="
echo "="
iptables -t nat -nvL POSTROUTING
echo "="
echo "="
iptables -t mangle -nvL ROUTING
echo "="
if [ $local_routing -eq 1 ]
    then
        echo "="
        iptables -t mangle -nvL LOCAL_ROUTING
fi
}

case $1 in
start)   Who_Am_I
         start
         ;;

restart) Who_Am_I
         stop
         start
         ;;
stop)    Who_Am_I
         stop
         ;;
status)  Who_Am_I
         status
         ;;

*)       echo "usage $0 [stop|start|restart|status]"
         ;;
esac
