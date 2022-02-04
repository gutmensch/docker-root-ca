FROM alpine:3.15

COPY cfg /

ARG CA_DIR="/CA"
ARG CA_CFG="-config /openssl-ca.cnf -batch"
ARG CA_NAME="docker-root-ca"
ARG CA_PASSWORD

ARG SERVER_CFG="-config /openssl-server.cnf -batch"

# 10.0.0.10:openldap,ldap 10.0.0.21:mysqldb,percona 10.0.0.22:mongodb [...]
ARG SERVER_CERTS
ARG IPV6_PREFIX

RUN mkdir $CA_DIR
WORKDIR $CA_DIR

RUN apk -U add bash openssl ca-certificates \
  && bash -c "mkdir -p {reqs,newcerts,certs,crl,private} 2>/dev/null || true; chmod 700 private" \
  && touch index.txt \
  \
  # create CA request and Key \
  && openssl req $CA_CFG -new -keyout private/${CA_NAME}.key -out reqs/${CA_NAME}.csr \
  \
  # sign CA \
  && openssl ca $CA_CFG -create_serial -passin pass:$CA_PASSWORD -out certs/${CA_NAME}.crt \
     -days 1825 -keyfile private/${CA_NAME}.key -selfsign -extensions v3_ca_has_san \
     -infiles reqs/${CA_NAME}.csr \
  \
  # print capabilities of CA \
  && openssl x509 -purpose -inform PEM < certs/${CA_NAME}.crt \
  \
  # add root CA to cert store \
  && cat certs/${CA_NAME}.crt >> /etc/ssl/certs/ca-certificates.crt \
  && update-ca-certificates \
  \
  # server certificates \
  && for s in $SERVER_CERTS; do \
      ipv4=$(echo $s | cut -d: -f1); \
      ipv6="${IPV6_PREFIX}$(echo $ipv4 | cut -d. -f4)"; \
      hosts=$(echo $s | cut -d: -f2); \
      san_list="IP.1: ${ipv4}, IP.2: ${ipv6}"; \
      index=1; \
      for i in $(echo $hosts | tr ',' ' '); do \
          if [ $index -eq 1 ]; then \
	      host=$i ; \
	  fi; \
          san_list="${san_list}, DNS.${index}: ${i}"; \
          let index="${index} + 1"; \
      done; \
      \
      # create server csr \
      openssl req $SERVER_CFG -new -subj "/O=bln.space/OU=Docker Services/CN=${host}" -nodes \
      -keyout private/${host}.key -out reqs/${host}.csr -addext "subjectAltName = ${san_list}"; \
      \
      # sign server csr \
      openssl ca $CA_CFG -create_serial -passin pass:$CA_PASSWORD -policy policy_server \
      -extensions signing_req -in reqs/${host}.csr -out certs/${host}.crt; \
      \
      # print server cert \
      openssl x509 -noout -text < certs/${host}.crt; \
  done \
  && find . -type f
