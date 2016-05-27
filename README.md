# Policy-Routing
-REQUIREMENTS

iproute2
iptables

-INSTRUCTIONS

add two (if you have two ISP connections) routing tables in /etc/iproute2/rt_tables
i.e

252     isp1

251     isp2

In my scenario eth1 and eth2 are the interfaces connected to the ISP and the ip confiugred are:

isp1_interface=eth1

isp1_ip->10.4.0.146

isp1_netmask=255.255.255.0

isp1_gw->10.4.0.1

isp2_interface=eth2

isp2_ip->192.168.124.2

isp2_netmask=255.255.255.0

isp2_gw=192.168.124.1

lan_int=eth0

lan_subnet=192.168.122.0/24

#add routes to the routing tables

ip route add $isp1_network dev $isp1_interface src $isp1_ip table isp1

ip route add default via $isp1_gw table isp1

ip route add $isp2_network dev $isp2_interface src $isp2_ip table isp2

ip route add default via $isp2_gw table isp2

#create policy routing rules for wan interfaces
ip rule add from $isp1_ip table isp1

ip rule add from $isp2_ip table isp2


now,if you want to send out from a specific interface some traffic you may use iptables.
For example,let's send out from isp2 the http traffic that comes from 192.168.122.0/24 (subnet defined for the lan)

iptables -t mangle -A PREROUTING -i $lan_int -m state --state ESTABLISHED,RELATED -m connmark ! --mark 0 -j CONNMARK --restore-mark

iptables -t mangle -A PREROUTING -s $lan_subnet -p tcp --dport 80 -m state --state NEW -m connmark --mark 0 -j MARK --set-mark 251

iptables -t mangle -A PREROUTING -m state --state NEW -m mark ! --mark 0 -j CONNMARK --save-mark

this is valid if the connection from the $lan_subnet  direct to anything that is not a local destination.
Then add a routing rule that lookup in the ips table if the fwmark match
ip rule add fwmark 251 table isp2

and nat the connection

iptables -t nat -A POSTROUTING -o eth2 -j MASQUERADE

iptables -t nat -A POSTROUTING -o eth1 -j MASQUERADE

remember also to enable the ip forwarding with

sysctl -w net.ipv4.ip_forward=1

and to disable the rp_filter,otherwise could happen that some packets will be dropped

echo 0 > /proc/sys/net/ipv4/conf/all/rp_filter


#USAGE

you'll find a bash script ,that will do what i mentioned above.
All paramters are read from a conmfiugration file.
You need only to run the script from a root termimal in this way

./scriptname.sh
