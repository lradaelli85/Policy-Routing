#!/usr/bin/python
# -*- coding: utf-8 -*-.
#
from ConfigParser import SafeConfigParser
import os.path

class ConfigHandler():
    '''Wrapper to get options and values from configuartion file '''
    def __init__(self,configuration_file):
        self.parser = SafeConfigParser()
        if os.path.isfile(configuration_file):
            self.parser_read = self.parser.read(configuration_file)
        else:
           print 'file %s does not exists' % configuration_file

    def get_options(self,section):
        return self.parser.options(section)

    def get_values(self,section,option):
        if self.parser.get(section,option).find(',') > -1:
            value = self.parser.get(section,option).split(',')
        else:
            value = self.parser.get(section,option)
        return value

    def get_sections(self):
        return self.parser.sections()
