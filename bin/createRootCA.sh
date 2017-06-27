#!/bin/bash

set -e

DAYS=365
ROOT_CA="rootCA"

read -p "Root CA file [${ROOT_CA}]: " input
ROOT_CA=${input:-$ROOT_CA}

read -p "Root CA validity period in days [${DAYS}]: " input
DAYS=${input:-$DAYS}

openssl genrsa -aes256 -out ${ROOT_CA}.key 2048

openssl req -x509 -new -nodes -key ${ROOT_CA}.key -sha256 -days $DAYS -out ${ROOT_CA}.pem
