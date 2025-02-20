#!/bin/bash

def generate_ca [] {
    if ("ca.key" | path exists) {
        print "CA already exists"
        return
    }

    # Generate new local root CA
    openssl genrsa -out ca.key 4096
    (
        openssl req -x509 -new -nodes -key ca.key -sha256 -days 1825
        -subj "/C=US/ST=CA/O=LocalDev Org./CN=traefik.localdev"
        -out ca.crt
    )
    print "Generated new root CA, this one you need to add to your browser/OS:"
    open ca.crt | print
}

def generate_cert [] {
    # Generate domain cert for *.localdev
    print "Generating cert for domain *.localdev"

    openssl genrsa -out localdev.key 4096
    let temp_file = (mktemp)
    if ("/opt/homebrew/etc/openssl@3/openssl.cnf" | path exists) {
        open /opt/homebrew/etc/openssl@3/openssl.cnf | save -a $temp_file
    } else if ("/usr/local/etc/openssl/openssl.cnf" | path exists) {
        open /usr/local/etc/openssl/openssl.cnf | save -a $temp_file
    } else if ("/etc/openssl/openssl.cnf" | path exists) {
        open /etc/openssl/openssl.cnf | save -a $temp_file
    } else {
        error make {msg: "Cannot find openssl.cnf file"}
    }

    "\n[SAN]\nsubjectAltName=DNS:traefik.localdev,DNS:*.localdev,DNS:*.*.localdev,DNS:*.*.*.localdev,DNS:*.*.*.*.localdev" | save -a $temp_file
    (
        openssl req -new -sha256 -key localdev.key
        -subj "/C=US/ST=CA/O=LocalDev Org./CN=traefik.localdev"
        -reqexts SAN
        -config $temp_file
        -out localdev.csr
    )
    rm $temp_file

    # print "Generated CSR with the following details:"
    # openssl req -in localdev.csr -noout -text | print
}

def sign_cert [] {
    # Sign local cert, so it is accepted by the browser if you installed the local root CA
    print "Signing cert with the local root CA"

    let temp_file = (mktemp)
    "subjectAltName=DNS:traefik.localdev,DNS:*.localdev,DNS:*.*.localdev,DNS:*.*.*.localdev,DNS:*.*.*.*.localdev" | save -a $temp_file
    (
        openssl x509 -req -in localdev.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out localdev.crt -days 1825 -sha256
        -extfile $temp_file
    )
    rm $temp_file

    print "Signed cert with the following details:"
    openssl x509 -in localdev.crt -text -noout | print
}

export def main [] {
    generate_ca
    generate_cert
    sign_cert
}
