#! /bin/bash

###
# Quick shorthand script to search the user's .bash_history file.
#
# Written by: Kevin S. Clarke <ksclarke@gmail.com>
###

cat ~/.bash_history |grep $1
