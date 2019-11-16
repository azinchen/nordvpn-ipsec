FROM arm32v6/alpine:latest
COPY qemu-arm-static /usr/bin/

LABEL maintainer="Alexander Zinchenko <alexander@zinchenko.com>"

ENV URL_NORDVPN_API="https://api.nordvpn.com/server" \
    URL_RECOMMENDED_SERVERS="https://nordvpn.com/wp-admin/admin-ajax.php?action=servers_recommendations" \
    URL_OVPN_FILES="https://downloads.nordcdn.com/configs/archives/servers/ovpn.zip" \
    PROTOCOL=openvpn_udp \
    MAX_LOAD=70 \
    RANDOM_TOP=0 \
    CHECK_CONNECTION_ATTEMPTS=5 \
    CHECK_CONNECTION_ATTEMPT_INTERVAL=10

ADD https://github.com/just-containers/s6-overlay/releases/download/v1.22.1.0/s6-overlay-armhf.tar.gz /tmp/s6-overlay.tar.gz

RUN echo "**** upgrade packages ****" && \
    apk --no-cache --no-progress upgrade && \
    echo "**** install packages ****" && \
    apk --no-cache --no-progress add bash curl unzip tar iptables ip6tables jq openvpn && \
    echo "**** add s6 overlay ****" && \
    tar xfz /tmp/s6-overlay.tar.gz -C / && \
    echo "**** create folders ****" && \
    mkdir -p /vpn && \
    mkdir -p /ovpn && \
    echo "**** cleanup ****" && \
    apk del --purge tar && \
    rm -rf /tmp/* && \
    rm -rf /var/cache/apk/*

COPY root/ /

RUN chmod +x /app/*

VOLUME ["/ovpn"]

ENTRYPOINT ["/init"]
