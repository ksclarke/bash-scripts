#! /bin/bash

#===========================================================================
# A script to wrap Pidgin, resolving its Microsoft Lync compatibility issue
#===========================================================================

export NSS_SSL_CBC_RANDOM_IV=0
/usr/bin/pidgin
