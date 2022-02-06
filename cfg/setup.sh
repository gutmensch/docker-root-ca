#!/bin/sh

set -e

add_ca() {
    echo "adding docker root CA to trusted certificates"
    # quick and dirty detection
    if [ -n "$(which update-ca-trust || true)" ]; then
        add_ca_redhat
    elif [ -n "$(which apk || true)" ]; then
        add_ca_alpine
    else
	add_ca_debian
    fi
}

add_ca_redhat() {
    yum update || true
    yum install ca-certificates openssl || true
    ln -svf $PWD/ca.crt /etc/pki/ca-trust/source/anchors/docker_root_ca.crt
    update-ca-trust extract
    verify_cert ca
}

add_ca_debian() {
    apt update || true
    apt install ca-certificates openssl || true
    ln -svf $PWD/ca.crt /usr/local/share/ca-certificates/docker_root_ca.crt
    update-ca-certificates
    verify_cert ca
    rm -rf /var/lib/apt/lists/*
}

add_ca_alpine() {
    apk -U add ca-certificates openssl || true
    ln -svf $PWD/ca.crt /usr/local/share/ca-certificates/docker_root_ca.crt
    update-ca-certificates
    verify_cert ca
}

# align server cert location for all images
# /etc/ssl/certs/server.crt - server certificate
# /etc/ssl/certs/server.key - server certificate key without password
# /etc/ssl/certs/ca.crt - certificate authority
# /etc/ssl/certs/dhparams.pem - diffie hellman parameters for pfs
add_server_cert() {
    echo "adding server certificate $(basename $PWD) for user id ${1}"
    if [ -f $PWD/server.crt -a -f $PWD/server.key ]; then
        ln -svf $PWD/server.crt $PWD/../server.crt
        ln -svf $PWD/server.key $PWD/../server.key
        ln -svf $PWD/ca.crt $PWD/../ca.crt
        ln -svf $PWD/dhparams.pem $PWD/../dhparams.pem
	chown $1 server.*
	chmod 400 server.key
	verify_cert server
    else
	echo "server cert files missing"
	exit 1
    fi
}

verify_cert() {
    openssl verify -verbose $PWD/$1.crt || echo "could not verify cert without openssl, continuing"
}

# start script
if [ $(id -u) -ne 0 ]; then
    echo "${0} must be called as root"
    exit 1
fi

cd $(dirname $0)

add_ca

if [ -n "${1}" ]; then
    # owner id of server certificate means install server certificate
    # from caller directory, e.g. ldap or mysqldb
    add_server_cert $1
fi
