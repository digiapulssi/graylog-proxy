# Graylog Proxy

Provides proxy for Graylog Sidecar that secures access to remote Graylog REST
API and beats communication using client certificate.

![Graylog proxy setup](https://github.com/digiapulssi/graylog-proxy/raw/master/documentation/graylog-proxy-setup.png)

Port numbers on picture above are for default deployment scenario.

The proxy container is based on alpine version of [HAProxy docker container](https://hub.docker.com/_/haproxy/).

## Usage

The container requires PEM files for client and server certificates to establish
secure communication to server. The server certificate PEM must contain full
trust chain of certificates (including root CA certificate). Client certificate
PEM must contain the client certificate and issuer CA certificate followed by
client's private key.

Copy the certificate PEM files for client (client.pem) and server (ca.pem) to
docker host (suggested directory /etc/haproxy/cert) and modify their ownership
to root and mode to 400.

To create and start the proxy container run:
`docker run -d --name graylog-proxy -p 8080:8080 -p 5044:5044 -v <path-to-certificates>:/usr/local/etc/haproxy/cert -e LOGGING_SERVER=<graylog-server-name> digiapulssi/graylog-proxy`

Additionally port numbers can be customized by environment variables:
* API_PUBLISH_PORT - published port of API (default 8080), modify container's published port accordingly
* BEATS_PUBLISH_PORT - published port of beats (default 5044), modify container's published port accordingly
* API_SERVER_PORT - API port on server (default 8443)
* BEATS_SERVER_PORT - beats port on server (default 5044)

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
