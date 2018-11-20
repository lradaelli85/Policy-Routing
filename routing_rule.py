#!/usr/bin/python
# -*- coding: utf-8 -*-.
from utils.ConfigHandler import ConfigHandler
from utils.RunCommand import Command
import sys

parsed_value = {'src-ip' : '-s','src-net' : '-s', 'src-interface' : '-i',
               'protocol' : '-p', 'dst-port' : '--dport', 'dst-ip' : '-d',
               'dst-net' : '-d'}

def get_gw_mark():
    marks = {}
    with open('network.conf','r') as f:
        for line in f:
            if line.split('=')[0].endswith('_mark'):
                marks[line.split('=')[0].split('_')[0]] = line.split('=')[1].replace('\"','')
    return marks

def add_rule(chain,rule,mark):
    rules = []
    rules.append('iptables -t mangle -A {} {} -m mark --mark 0 -j MARK --set-mark {}'.format(chain,rule,mark))
    rules.append('iptables -t mangle -A {} {} -m mark ! --mark 0 -j RETURN'.format(chain,rule))
    for r in rules:
        out = Command(r).run()
        if out != 0:
            print 'error running \n{}'.format(r)

def get_rules(chain):
    local_chain = ''
    cfg_handler = ConfigHandler('routing.cfg')
    rules = cfg_handler.get_sections()
    marks = get_gw_mark()
    for rule in rules:
        opt = cfg_handler.get_options(rule)
        if opt[len(opt)-1] == 'routing_type' and cfg_handler.get_values(rule,opt[len(opt)-1]) == chain:
            ipt_rule = ''
            for rule_data in opt:
                if cfg_handler.get_values(rule,rule_data) and (rule_data != 'gw' and
                 rule_data != 'routing_type'):
                    ipt_rule +=' '+parsed_value[rule_data]+' '+cfg_handler.get_values(rule,rule_data)
            rule_mark = marks[cfg_handler.get_values(rule,'gw')]
            add_rule(chain.upper(),ipt_rule,rule_mark)

if __name__ == "__main__":
    get_rules(sys.argv[1].lower())
