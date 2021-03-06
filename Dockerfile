FROM alpine:edge

COPY cfg /

ARG CA_DIR="/CA"
ARG CA_CFG="-config /openssl-ca.cnf -batch"
ARG CA_NAME="docker-root-ca"
ARG CA_DAYS=3650
ARG CA_PASSWORD

ARG SERVER_CFG="-config /openssl-server.cnf -batch"
ARG SERVER_DAYS=1825

ARG RSA_KEY_SIZE=4096

# 10.0.0.10:openldap,ldap 10.0.0.21:mysqldb,percona 10.0.0.22:mongodb [...]
ARG SERVER_CERTS
ARG IPV6_PREFIX

RUN mkdir $CA_DIR
WORKDIR $CA_DIR

RUN apk -U add bash openssl ca-certificates \
  && bash -c "mkdir -p {reqs,newcerts,certs,crl,private} 2>/dev/null || true; chmod 700 private" \
  && touch index.txt \
  \
  # source helper functions for openssl date and server certs var parsing \
  && source /helper.sh \
  \
  # create dhparams for tls configs which support it \
  && openssl dhparam -out certs/dhparams.pem 4096 \
  \
  # create CA request and Key \
  && openssl req $CA_CFG -new -keyout private/${CA_NAME}.key -out reqs/${CA_NAME}.csr \
  && chmod 400 private/${CA_NAME}.key \
  \
  # sign CA \
  && openssl ca $CA_CFG -create_serial -passin pass:$CA_PASSWORD -notext -out certs/${CA_NAME}.crt \
     -days $CA_DAYS -keyfile private/${CA_NAME}.key -selfsign -extensions v3_ca \
     -infiles reqs/${CA_NAME}.csr \
  \
  # print capabilities of CA \
  && openssl x509 -noout -purpose -inform PEM < certs/${CA_NAME}.crt \
  && openssl x509 -noout -text -inform PEM < certs/${CA_NAME}.crt \
  \
  # add root CA to cert store \
  && cp certs/${CA_NAME}.crt /usr/local/share/ca-certificates/ \
  && update-ca-certificates \
  \
  # server certificates \
  && for s in $SERVER_CERTS; do \
       host="$(get_cn $s)"; \
       san_list="$(get_san $s $IPV6_PREFIX)"; \
       mkdir certs/$host; \
       \
       # create server csr \
       openssl req $SERVER_CFG -new -subj "/O=bln.space/OU=Docker Services/CN=${host}" -nodes \
       -keyout certs/$host/server.key -out reqs/$host.csr -addext "subjectAltName = ${san_list}"; \
       \
       # sign server csr \
       openssl ca $CA_CFG -create_serial -passin pass:$CA_PASSWORD -policy policy_server \
       -extensions signing_req -in reqs/$host.csr -out certs/$host/server.crt; \
       \
       # print server cert \
       openssl x509 -noout -text < certs/$host/server.crt; \
       \
       # verify cert against cert store \
       openssl verify -verbose certs/$host/server.crt; \
       \
       # copy dhparams, root ca and bundle to host dir for easier copy later \
       # copy setup.sh too to make easier for images to adopt root CA and server cert \
       cp certs/dhparams.pem certs/$host/; \
       cp certs/$CA_NAME.crt certs/$host/ca.crt; \
       cp /etc/ssl/certs/ca-certificates.crt certs/$host/ca-bundle.crt; \
       cp /setup.sh certs/$host/setup.sh; \
    done \
  # common directory for images without server cert but with CA setup \
  && mkdir certs/common \
  && cp certs/dhparams.pem certs/common/ \
  && cp certs/$CA_NAME.crt certs/common/ca.crt \
  && cp /etc/ssl/certs/ca-certificates.crt certs/common/ca-bundle.crt \
  && cp /setup.sh certs/common/ \
  && find /CA -type f
