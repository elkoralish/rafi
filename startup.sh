#!/bin/bash
# vim: syntax=sh:tabstop=4:expandtab
cd code/peatio && god -c lib/daemons/daemons.god && bundle exec rails server -p 3000
cd ~/code/peatio-trading-ui && bundle exec rails server -p 4000
