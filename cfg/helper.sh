#!/bin/sh

get_ipv4() {
    echo $1 | cut -d: -f1
}

get_ipv6() {
    echo "${2}$(echo $(get_ipv4 $1) | cut -d. -f4)"
}

get_cn() {
    hosts=$(echo $1 | cut -d: -f2)
    echo $hosts | cut -d, -f1
}

get_san() {
    san_list="IP.1: $(get_ipv4 $1), IP.2: $(get_ipv6 $1 $IPV6_PREFIX)"
    hosts=$(echo $1 | cut -d: -f2)
    index=1
    for i in $(echo $hosts | tr ',' ' '); do
        if [ $index -eq 1 ]; then
            host=$i
        fi;
        san_list="${san_list}, DNS.${index}: ${i}"
        let index="${index} + 1"
    done
    echo $san_list
}
