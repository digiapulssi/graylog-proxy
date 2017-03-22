# Graylog Proxy

Provides proxy for Graylog Sidecar that secures access to remote Graylog REST
API and beats communication using client certificate.

![Graylog proxy setup](https://github.com/digiapulssi/graylog-proxy/raw/master/documentation/graylog-proxy-setup.png)

Port numbers on picture above are for default deployment scenario.

The proxy container is based on alpine version of [HAProxy docker container](https://hub.docker.com/_/haproxy/).

## Usage

The container requires PEM files for client and server certificates to establish
secure communication to server.

The server certificate PEM (server_ca.pem) must contain full trust chain of certificates
(including root CA certificate) because proxy does not trust any root CAs by
default. For example, if your server certificate is signed by DigiCert Issuer CA
you will need server_ca.pem with:
- Your server certificate
- DigiCert Issuer CA which signed your server certificate
- DigiCert Root CA which signed DigiCert Issuer CA

Client certificate PEM (client.pem) must contain the client certificate and issuer CA
certificate followed by client's private key. See below on how to create private
CA and client certificate.

Copy the certificate PEM files for client (client.pem) and server (server_ca.pem) to
docker host (suggested directory /etc/haproxy/cert) and modify their ownership
to root and mode to 400.

To create and start the proxy container run:
`docker run -d --name graylog-proxy -p 8080:8080 -p 5044:5044 -v <path-to-certificates>:/usr/local/etc/haproxy/cert -e LOGGING_SERVER=<graylog-server-name> digiapulssi/graylog-proxy`

Additionally port numbers can be customized by environment variables:
* API_PUBLISH_PORT - published port of API (default 8080), modify container's published port accordingly
* BEATS_PUBLISH_PORT - published port of beats (default 5044), modify container's published port accordingly
* API_SERVER_PORT - API port on server (default 8443)
* BEATS_SERVER_PORT - beats port on server (default 5044)

### Creating Private Root CA and CA Signed Client Certificate

1. To create root CA, execute `bin/createRootCA.sh` and fill in data. Example:

```
[graylog-proxy]$./createRootCA.sh
Root CA file [rootCA]:
Root CA validity period in days [365]:
Generating RSA private key, 2048 bit long modulus
.............................+++
....................+++
e is 65537 (0x10001)
You are about to be asked to enter information that will be incorporated
into your certificate request.
What you are about to enter is what is called a Distinguished Name or a DN.
There are quite a few fields but you can leave some blank
For some fields there will be a default value,
If you enter '.', the field will be left blank.
-----
Country Name (2 letter code) [XX]:FI
State or Province Name (full name) []:Länsi-Suomi
Locality Name (eg, city) [Default City]:Tampere
Organization Name (eg, company) [Default Company Ltd]:Digia Finland Oy
Organizational Unit Name (eg, section) []:IMS
Common Name (eg, your name or your server's hostname) []:ABC Root CA
Email Address []:
```

Configure generated CA certificate as accepted CA on server side. Keep root CA
private key (rootCA.key in example) and certificate (rootCA.pem) stored securely.

2. To create client certificate, execute `bin/createClientCert.sh` and fill in data. Example:

```
[graylog-proxy]$./createClientCert.sh
Client certificate name [client]:
Client certificate validity period in days [365]:
Root CA name [rootCA]:
Generating RSA private key, 2048 bit long modulus
....................................................+++
....................................................................+++
e is 65537 (0x10001)
You are about to be asked to enter information that will be incorporated
into your certificate request.
What you are about to enter is what is called a Distinguished Name or a DN.
There are quite a few fields but you can leave some blank
For some fields there will be a default value,
If you enter '.', the field will be left blank.
-----
Country Name (2 letter code) [XX]:FI
State or Province Name (full name) []:Länsi-Suomi
Locality Name (eg, city) [Default City]:Tampere
Organization Name (eg, company) [Default Company Ltd]:Digia Finland Oy
Organizational Unit Name (eg, section) []:IMS
Common Name (eg, your name or your server's hostname) []:ABC Client Certificate
Email Address []:

Please enter the following 'extra' attributes
to be sent with your certificate request
A challenge password []:
An optional company name []:
Signature ok
subject=/C=FI/ST=L\xC3\x83\xC2\xA4nsi-Suomi/L=Tampere/O=Digia Finland Oy/OU=IMS/CN=ABC Client Certificate
Getting CA Private Key
```

Use generated PEM file (client.pem in example) for graylog proxy. It includes both private key and CA signed certificate.

## Getting Logs from Proxy

The proxy is configured to log to docker host's rsyslog via local2 facility.
To configure logs enable UDP 514 port in /etc/rsyslog.conf:

```
$ModLoad imudp
$UDPServerRun 514
```

then create configuration file /etc/rsyslog.d/haproxy.conf:

```
local2.* /var/log/haproxy.log
```

and restart rsyslog:

`systemctl restart rsyslog.service`
