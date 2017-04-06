#!/bin/bash

DAYS=365
ROOT_CA="rootCA"
CLIENT="client"

read -p "Client certificate name [${CLIENT}]: " input
CLIENT=${input:-$CLIENT}

read -p "Client certificate validity period in days [${DAYS}]: " input
DAYS=${input:-$DAYS}

read -p "Root CA name [${ROOT_CA}]: " input
ROOT_CA=${input:-$ROOT_CA}

# Generate client key
openssl genrsa -out ${CLIENT}.key 2048

# Generate client certificate request
openssl req -new -key ${CLIENT}.key -out ${CLIENT}.csr

# Sign certificate request
openssl x509 -req -in ${CLIENT}.csr -CA ${ROOT_CA}.pem -CAkey ${ROOT_CA}.key -CAcreateserial -out ${CLIENT}.crt -days $DAYS -sha256

# Create client PEM
cat ${CLIENT}.crt >${CLIENT}.pem
cat ${ROOT_CA}.pem >>${CLIENT}.pem
cat ${CLIENT}.key >>${CLIENT}.pem
