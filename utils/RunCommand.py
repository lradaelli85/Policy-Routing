#!/usr/bin/python
# -*- coding: utf-8 -*-.

import subprocess
from shlex import split
from sys import exc_info

class Command:
    '''Wrapper to run Linux shell commands using Popen'''
    def __init__(self,command):
        self.command = command

    def run(self,OnlyExitStatus=True):
        '''run a command and returns its exit status
           To return also command output set OnlyExitStatus=False
        '''
        if '|' in self.command:
            cmd = []
            for pipe in self.command.split('|'):
                cmd.append(pipe)
        else:
            cmd = self.command
        output = False
        exit_status = 0
        if type(cmd) is list:
            counter = 0
            proc = {}
            for cmd_splitted in cmd:
                if counter == 0:
                    try:
                        proc[counter] = subprocess.Popen(split(cmd_splitted),stdout=subprocess.PIPE)
                    except:
                        exit_status = exc_info()[1]
                elif counter > 0 and counter < len(cmd):
                    try:
                        proc[counter] = subprocess.Popen(split(cmd_splitted),
                                        stdin=proc[counter-1].stdout,stdout=subprocess.PIPE,
                                        stderr=subprocess.PIPE)
                    except:
                        if len(proc) > 0:
                            proc[0].stdout.close()
                            proc[0].wait()
                        exit_status = exc_info()[1]
                counter +=1
            try:
                output = proc[counter-1].communicate()
                exit_status = proc[0].wait()
            except:
                exit_status = exc_info()[1]
        else:
            try:
                cmd_part = subprocess.Popen(split(self.command),stdin=None,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
                output = cmd_part.communicate()
                exit_status = cmd_part.wait()
            except:
                exit_status = exc_info()[1]
        if not OnlyExitStatus:
            return output,exit_status
        else:
            return exit_status
