#!/bin/bash
# vim: syntax=sh:tabstop=4:expandtab
# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
#
# Startup script for peatio daemons and puma servers
# This shouldn't really be necessary but for some reason systemd is having 
# a hard time handling it.  For now, this should be run as the peatio user
# in a login shell to start everything after a reboot
#
# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
cd code/peatio && god -c lib/daemons/daemons.god && bundle exec rails server -p 3000 &
cd ~/code/peatio-trading-ui && bundle exec rails server -p 4000 &
