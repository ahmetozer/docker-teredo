#!/bin/bash

if [ -f "/var/run/netns/container" ]
then
    exec_command="ip netns exec container"
else
    exec_command="bash -c"
fi

printf "Enabling IPv6 " ; eval $exec_command sysctl net.ipv6.conf.all.disable_ipv6=0 > /dev/null && echo "OK." || ( printf "ERR"; err_on_exit="yes" )
printf "Enabling IPv6 by default " ; eval $exec_command sysctl net.ipv6.conf.default.disable_ipv6=0 > /dev/null && echo "OK." || ( printf "ERR"; err_on_exit="yes" )
printf "Enabling IPv6 by local " ; eval $exec_command sysctl net.ipv6.conf.lo.disable_ipv6=0 > /dev/null && echo "OK." || ( printf "ERR"; err_on_exit="yes" )

if [ "$err_on_exit" == "yes" ]
then
    echo "System has a errors. Did you run this container with --privileged argument ?"
    sleep 5
    exit 1
fi
$exec_command miredo -f