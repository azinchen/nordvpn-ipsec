[![logo](https://github.com/azinchen/nordvpn/raw/master/NordVpn_logo.png)](https://www.nordvpn.com/)

# NordVPN

[![Docker Pulls][dockerhub-badge]][dockerhub-link]

This is an OpenVPN client docker container that use least loaded NordVPN servers. It makes routing containers' traffic through OpenVPN easy.

# What is OpenVPN?

OpenVPN is an open-source software application that implements virtual private network (VPN) techniques for creating secure point-to-point or site-to-site connections in routed or bridged configurations and remote access facilities. It uses a custom security protocol that utilizes SSL/TLS for key exchange. It is capable of traversing network address translators (NATs) and firewalls.

# How to use this image

This container was designed to be started first to provide a connection to other containers (using `--net=container:vpn`, see below *Starting an NordVPN client instance*).

**NOTE**: More than the basic privileges are needed for NordVPN. With docker 1.2 or newer you can use the `--cap-add=NET_ADMIN` and `--device /dev/net/tun` options. Earlier versions, or with fig, and you'll have to run it in privileged mode.

**NOTE 2**: If you need a template for using this container with `docker-compose`, see the example [file](https://github.com/dperson/openvpn-client/raw/master/docker-compose.yml).

## Supported Architectures

The image supports multiple architectures such as `amd64`, `arm` and `arm64`.

The new features are introduced to 'edge' version, but this version might contain issues. Avoid to use 'edge' image in production environment.

The architectures supported by this image are:

| Architecture | Tag |
| :----: | --- |
| x86-64, armhf, aarch64 | latest |
| x86-64, armhf, aarch64 | edge |

## Starting an NordVPN instance

```
docker run -ti --cap-add=NET_ADMIN --device /dev/net/tun --name vpn \
           -e USER=user@email.com -e PASS=password \
           -e RANDOM_TOP=n -e RECREATE_VPN_CRON=string \
           -e COUNTRY=country1;country2 -e CATEGORY=category1;category2 \
           -e PROTOCOL=protocol -d azinchen/nordvpn
```

Once it's up other containers can be started using it's network connection:

```
docker run -it --net=container:vpn -d some/docker-container
```

## docker-compose

```
version: "3"
services:
  vpn:
    image: azinchen/nordvpn:latest
    cap_add:
      - net_admin
    devices:
      - /dev/net/tun
    environment:
      - USER=user@email.com
      - PASS='pas$word'
      - COUNTRY=Spain;Switzerland
      - CATEGORY=P2P
      - RANDOM_TOP=10
      - RECREATE_VPN_CRON=5 */3 * * *
      - NETWORK=192.168.1.0/24;192.168.2.0/24
      - OPENVPN_OPTS=--mute-replay-warnings
    ports:
      - 8080:80
    restart: unless-stopped
  
  web:
    image: nginx
    network_mode: service:vpn
```

## Filter NordVPN servers

This container selects least loaded server from NordVPN pool. Server list can be filtered by setting `COUNTRY`, `CATEGORY` and/or `PROTOCOL` environment variables. If filtered list is empty, recommended server is selected.

## Reconnect by cron

This container selects server and its config during startup and maintains connection until stop. Selected server might be changed using cron via `RECREATE_VPN_CRON` environment variable.

```
docker run -ti --cap-add=NET_ADMIN --device /dev/net/tun --name vpn \
           -e RECREATE_VPN_CRON="5 */3 * * *" -e RANDOM_TOP=10
           -e USER=user@email.com -e PASS=password -d azinchen/nordvpn
```

In this example the VPN connection will be reconnected in the 5th minute every 3 hours.

## Check Internet connection by cron

This container checks Internet connection via VPN by cron.

```
docker run -ti --cap-add=NET_ADMIN --device /dev/net/tun --name vpn \
           -e CHECK_CONNECTION_CRON="*/5 * * * *" -e CHECK_CONNECTION_URL="https://www.google.com"
           -e USER=user@email.com -e PASS=password -d azinchen/nordvpn
```

In this example the VPN connection will be checked every 5 minutes.

## Local Network access to services connecting to the internet through the VPN

The environment variable NETWORK must be your local network that you would connect to the server running the docker containers on. Running the following on your docker host should give you the correct network: `ip route | awk '!/ (docker0|br-)/ && /src/ {print $1}'`

```
docker run -ti --cap-add=NET_ADMIN --device /dev/net/tun --name vpn \
           -p 8080:80 -e NETWORK=192.168.1.0/24 \ 
           -e USER=user@email.com -e PASS=password -d azinchen/nordvpn
```

Now just create the second container _without_ the `-p` parameter, only inlcude the `--net=container:vpn`, the port should be declare in the vpn container.

```
docker run -ti --rm --net=container:vpn -d bubuntux/riot-web
```

now the service provided by the second container would be available from the host machine (http://localhost:8080) or anywhere inside the local network (http://192.168.1.xxx:8080).

## Local Network access to services connecting to the internet through the VPN using a Web proxy

```
docker run -it --name web -p 80:80 -p 443:443 \
           --link vpn:<service_name> -d dperson/nginx \
           -w "http://<service_name>:<PORT>/<URI>;/<PATH>"
```

Which will start a Nginx web server on local ports 80 and 443, and proxy any requests under `/<PATH>` to the to `http://<service_name>:<PORT>/<URI>`. To use a concrete example:

```
docker run -it --name bit --net=container:vpn -d bubundut/nordvpn
docker run -it --name web -p 80:80 -p 443:443 --link vpn:bit \
           -d dperson/nginx -w "http://bit:9091/transmission;/transmission"
```

For multiple services (non-existant 'foo' used as an example):

```
docker run -it --name bit --net=container:vpn -d dperson/transmission
docker run -it --name foo --net=container:vpn -d dperson/foo
docker run -it --name web -p 80:80 -p 443:443 --link vpn:bit \
           --link vpn:foo -d dperson/nginx \
           -w "http://bit:9091/transmission;/transmission" \
           -w "http://foo:8000/foo;/foo"
```

## Reconnect
By the fault the container will try to reconnect to the same server when disconnected, in order to reconnect to another recommended server automatically add env variable:
```
 - OPENVPN_OPTS=--pull-filter ignore "ping-restart" --ping-exit 180
```

## Connectivity check

There are several environment variables which might be used to check the Internet connectivity thru the VPN connection, `CHECK_CONNECTION_CRON`, `CHECK_CONNECTION_URL`, `CHECK_CONNECTION_ATTEMPTS` and `CHECK_CONNECTION_ATTEMPT_INTERVAL`:
```
 - CHECK_CONNECTION_CRON=*/10 * * * *
 - CHECK_CONNECTION_URL=https://www.google.com;https://www.microsoft.com;https://www.apple.com;https://www.amazon.com
```

# Environment variables

Container images are configured using environment variables passed at runtime.

 * `COUNTRY`           - Use servers from countries in the list (IE Australia;New Zeland). Several countries can be selected using semicolon.
 * `CATEGORY`          - Use servers from specific categories (IE P2P;Anti DDoS). Several categories can be selected using semicolon. Allowed categories are:
   * `Dedicated IP`
   * `Double VPN`
   * `Obfuscated Servers`
   * `Onion Over VPN`
   * `P2P`
   * `Standard VPN servers`
 * `PROTOCOL`          - Specify OpenVPN protocol. Only one protocol can be selected. Allowed protocols are:
   * `openvpn_udp`
   * `openvpn_tcp`
 * `RANDOM_TOP`        - Place n servers from filtered list in random order. Useful with `RECREATE_VPN_CRON`.
 * `RECREATE_VPN_CRON` - Set period of selecting new server in format for crontab file. Disabled by default.
 * `CHECK_CONNECTION_CRON` - Set period of checking Internet connection in format for crontab file. Disabled by default.
 * `CHECK_CONNECTION_URL` - Use list of URI for checking Internet connection.
 * `CHECK_CONNECTION_ATTEMPTS` - Set number of attemps of checking. Default value is 5.
 * `CHECK_CONNECTION_ATTEMPT_INTERVAL` - Set sleep timeouts between failed attepms. Default value is 10.
 * `USER`              - User for NordVPN account.
 * `PASS`              - Password for NordVPN account.
 * `NETWORK`           - CIDR network (IE 192.168.1.0/24), add a route to allows replies once the VPN is up. Several networks can be added to route using semicolon.
 * `NETWORK6`          - CIDR IPv6 network (IE fe00:d34d:b33f::/64), add a route to allows replies once the VPN is up. Several networks can be added to route using semicolon.
 * `OPENVPN_OPTS`      - Used to pass extra parameters to openvpn [full list](https://openvpn.net/community-resources/reference-manual-for-openvpn-2-4/).

## Environment variable's keywords

The list of keywords for environment variables might be changed, check the allowed keywords by the following commands:

`COUNTRY`
```
curl -s https://api.nordvpn.com/server | jq -c '.[] | .country' | jq -s -a -c 'unique | .[]'
```

`CATEGORY`
```
curl -s https://api.nordvpn.com/server | jq -c '.[] | .categories[].name' | jq -s -a -c 'unique | .[]'
```

# Issues

If you have any problems with or questions about this image, please contact me through a [GitHub issue](https://github.com/azinchen/nordvpn/issues) or [email](mailto:alexander@zinchenko.com).

[dockerhub-badge]: https://img.shields.io/docker/pulls/azinchen/nordvpn?style=flat-square
[dockerhub-link]: https://hub.docker.com/repository/docker/azinchen/nordvpn
