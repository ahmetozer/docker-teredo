#!/bin/bash
if [ ! -z "$container_name" ]
then
    echo "Container name detected: $container_name"
    if [ -d "/proc2/" ]
    then
        echo "Second Proc area found."
        if [ -S "/var/run/docker.sock" ]
        then
            echo "Docker socket found."
            container_stat=$(curl --unix-socket /var/run/docker.sock http/containers/$container_name/json -s -o /dev/null -w '%{http_code}\n' )
            case $container_stat in
            "000")
                echo  "Err while connecting docker socket."
                echo  "Are you mount right docker socket ?"
            ;;

            "404")
                echo "Container $container_name is not found."
            ;;

            "200")
                echo "Container $container_name is found and running."
                if [ $(curl --unix-socket /var/run/docker.sock http/containers/$container_name/json -s | awk -v RS=',' -F: '{ if ( $1 == "\"Running\"") {print $2}}') == "true" ]
                then
                    container_pid=$(curl --unix-socket /var/run/docker.sock http/containers/$container_name/json -s | awk -v RS=',' -F: '{ if ( $1 == "\"Pid\"") {print $2}}')
                    rm /var/run/netns/container 2> /dev/null
                    mkdir -p /var/run/netns/
                    ln -s /proc2/$container_pid/ns/net /var/run/netns/container && echo "Link is created" || ( echo "Link is not created. Did you run this container with privileged ? "; exit 1)
                else
                    echo "Your container is not running."
                    exit 1
                fi
            ;;
            
            *)
                echo "Unknow response: $container_stat"
            ;;
            esac
        else 
            echo "You are mounted Proc folder but you are not mount docker sock."
            echo "You can make a mount with -v /var/run/docker.sock:/var/run/docker.sock"
        fi
    else
        echo "Second proc folder is not found."
        echo "Please mount second proc with docker with -v /proc/:/proc2"
    fi
fi

if [ -f "/var/run/netns/container" ]
then
    exec_command="ip netns exec container"
else
    exec_command=""
fi

printf "Enabling IPv6 " ; $exec_command sysctl net.ipv6.conf.all.disable_ipv6=0 > /dev/null && echo "OK." || { echo "ERR"; err_on_exit="yes" ;}
printf "Enabling IPv6 by default " ; $exec_command sysctl net.ipv6.conf.default.disable_ipv6=0 > /dev/null && echo "OK." || { echo "ERR"; err_on_exit="yes" ;}
printf "Enabling IPv6 by local " ; $exec_command sysctl net.ipv6.conf.lo.disable_ipv6=0 > /dev/null && echo "OK." || { echo "ERR"; err_on_exit="yes" ;}

if [ "$delro" == "yes" ]
then
    if [ -f "/var/run/netns/container" ]
    then
        echo "You are enable delete all default IPv6 route"
        $exec_command sysctl -w net.ipv6.conf.all.autoconf=0
        $exec_command sysctl -w net.ipv6.conf.all.accept_ra=0
        $exec_command ip -6 ro | grep default | while read IPv6_Route
        do
            echo Deleting route: $IPv6_Route
            $exec_command ip -6 ro del $IPv6_Route || echo "While deleting route $IPv6_Route, an err occured."
        done
    else
        echo "You are enable delete all default IPv6 route, but this function is disabled in HOST to preventing any connection issue"
    fi
fi

if [ "$err_on_exit" == "yes" ]
then
    echo "System has a errors. Did you run this container with --privileged argument ?"
    sleep 5
    exit 1
fi
$exec_command miredo -f