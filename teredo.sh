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
                err_on_exit="yes"
            ;;

            "404")
                echo "Container $container_name is not found."
                err_on_exit="yes"
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
                    echo "Exiting in 10 seconds."
                    sleep 10
                    exit 0
                fi
            ;;
            
            *)
                echo "Unknow response: $container_stat"
                err_on_exit="yes"
            ;;
            esac
        else 
            echo "You are mounted Proc folder but you are not mount docker sock."
            echo "You can make a mount with -v /var/run/docker.sock:/var/run/docker.sock"
            err_on_exit="yes"
        fi
    else
        echo "Second proc folder is not found."
        echo "Please mount second proc with docker with -v /proc/:/proc2"
        err_on_exit="yes"
    fi
fi

if [ -f "/var/run/netns/container" ]
then
    control_container="yes"
    exec_command="ip netns exec container"
else
    exec_command=""
fi

printf "Enabling IPv6 " ; $exec_command sysctl net.ipv6.conf.all.disable_ipv6=0 > /dev/null && echo "OK." || { echo "ERR"; err_on_exit="yes" ;}
printf "Enabling IPv6 by default " ; $exec_command sysctl net.ipv6.conf.default.disable_ipv6=0 > /dev/null && echo "OK." || { echo "ERR"; err_on_exit="yes" ;}
printf "Enabling IPv6 by local " ; $exec_command sysctl net.ipv6.conf.lo.disable_ipv6=0 > /dev/null && echo "OK." || { echo "ERR"; err_on_exit="yes" ;}


if [ "$err_on_exit" == "yes" ]
then
    echo "System has a errors. Did you run this container with --privileged argument ?"
    sleep 5
    exit 1
fi

if [ "$delro" == "yes" ]
then
    if [ -f "/var/run/netns/container" ]
    then
        echo "You are enable delete all default IPv6 route"
        $exec_command sysctl -w net.ipv6.conf.all.autoconf=0
        $exec_command sysctl -w net.ipv6.conf.all.accept_ra=0
        echo > ipv6_route_backup.txt
        current_ip=$(curl ahmetozer.org/cdn-cgi/tracert -s | awk -v RS='\n' -F"=" '{ if ( $1 == "ip") {print $2 }}')
        echo $current_ip > current_ip.txt
        $exec_command ip -6 rule add from $current_ip table 200
        $exec_command ip -6 ro | grep default | while read IPv6_Route
        do
            $exec_command ip -6 ro add $IPv6_Route table 200 || echo "While adding route from $current_ip with $IPv6_Route table 200, an err occured."
            echo $IPv6_Route >> ipv6_route_backup.txt
            echo Deleting route: $IPv6_Route
            $exec_command ip -6 ro del $IPv6_Route || echo "While deleting route $IPv6_Route, an err occured."
        done
    else
        echo "You are enable delete all default IPv6 route, but this function is disabled in HOST to preventing any connection issue"
    fi
fi

exit_trap() {
if [ "$exit_is_done" != "true" ]
then
    if [ "$delro" == "yes" ]
    then
        if [ -f "/var/run/netns/container" ]
        then
            echo "Backing up IPv6 Routes"
            $exec_command sysctl -w net.ipv6.conf.all.autoconf=1
            $exec_command sysctl -w net.ipv6.conf.all.accept_ra=1
            $exec_command ip -6 rule del from $current_ip table 200
            cat ipv6_route_backup.txt | grep default | while read IPv6_Route
            do
                $exec_command ip -6 ro del $IPv6_Route table 200 || echo "While delete route from $current_ip with $IPv6_Route table 200, an err occured."
                echo Loading route: $IPv6_Route
                $exec_command ip -6 ro add $IPv6_Route || echo "While adding route $IPv6_Route, an err occured."
            done
            rm ipv6_route_backup.txt 2> /dev/null
        fi
    fi
fi
exit_is_done="true"
}

trap exit_trap INT EXIT


healt_check() {
    err_count=0
    while [ -f "/var/run/netns/container" ]
    do
    ip netns exec container ip addr show dev teredo > /dev/null 2>&1
    if [ $? -eq 0 ]
    then
        err_count=0
    else
        err_count=$((err_count+1))
        if [ "$err_count" -gt "15" ]
        then
            echo "System cannot access to teredo interface"
            echo "This container is closed "
            kill $1
        fi
    fi
    
    sleep 2
    done
    echo "Container $container_name is closing."
    kill $1
}
if [ -f "/var/run/netns/container" ]
then
    healt_check $$ &
fi
$exec_command miredo -f