# docker-ca

* required build args

```
# CA signing key password
CA_PASSWORD=...

# ipv6 prefix used for SAN, last octet copied from ipv4 address for cert IP entry
IPV6_PREFIX=...

# example: "10.0.0.10:openldap,ldap 10.0.0.21:mysqldb,percona 10.0.0.22:mongodb"
SERVER_CERTS=
```

