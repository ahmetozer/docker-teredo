#!/bin/bash
if [ ! -z "$container_name" ]
then
    echo "Container name detected: $container_name"
    if [ -d "/proc2/"]
    then
        echo "Second Proc area found"
        if [ -f "/var/run/docker.sock" ]
        then
            echo "Docker socket found"
            container_stat=(curl --unix-socket /var/run/docker.sock http/containers/$container_name/json -s -o /dev/null -w '%{http_code}\n' )
            case $container_stat in
            "000")
                echo  "Err while connecting docker socket"
                echo  "Are you mount right docker socket ?"
            ;;

            "404")
                echo "Container $container_name is not found"
            ;;

            "200")
                if [ $(curl --unix-socket /var/run/docker.sock http/containers/$container_name/json -s | awk -v RS=',' -F: '{ if ( $1 == "\"Running\"") {print $2}}') == "true" ]
                then
                    container_pid=$(curl --unix-socket /var/run/docker.sock http/containers/$container_name/json -s | awk -v RS=',' -F: '{ if ( $1 == "\"Pid\"") {print $2}}')
                    rm /var/run/netns/container 2> /dev/null || echo "First time run"
                    ln -s /proc/$container_pid/ns/net /var/run/netns/container && echo "Link is created" || ( echo "Link is not created. Did you run this container with privileged ? "; exit 1)
                else
                    echo "Your container is not running"
                    exit 1
                fi
            ;;
            
            *)
                echo "Unknow response: $container_stat"
            ;;
            esac
        else 
            echo "You are mounted Proc folder but you are not mount docker sock"
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
    exec_command="bash -c"
fi

printf "Enabling IPv6 " ; eval $exec_command sysctl net.ipv6.conf.all.disable_ipv6=0 > /dev/null && echo "OK." || ( printf "ERR"; err_on_exit="yes" )
printf "Enabling IPv6 by default " ; eval $exec_command sysctl net.ipv6.conf.default.disable_ipv6=0 > /dev/null && echo "OK." || ( printf "ERR"; err_on_exit="yes" )
printf "Enabling IPv6 by local " ; eval $exec_command sysctl net.ipv6.conf.lo.disable_ipv6=0 > /dev/null && echo "OK." || ( printf "ERR"; err_on_exit="yes" )

if [ "redero" == "yes" ]
then
    echo "You are enable replace default route"
    ip -6 ro | grep default | while read IPv6_Route
    do
        echo Deleting route: $IPv6_Route
        ip -6 ro del $IPv6_Route || echo "While deleting route $IPv6_Route, an err occured."
    done
fi

if [ "$err_on_exit" == "yes" ]
then
    echo "System has a errors. Did you run this container with --privileged argument ?"
    sleep 5
    exit 1
fi
$exec_command miredo -f