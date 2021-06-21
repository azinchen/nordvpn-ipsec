FROM alpine:latest AS s6-builder

ARG TARGETPLATFORM

RUN echo "**** upgrade packages ****" \
    && apk --no-cache --no-progress upgrade \
    && echo "**** install packages ****" \
    && apk --no-cache --no-progress add tar \
    && echo "**** create folders ****" \
    && mkdir -p /s6 \
    && echo "**** download s6 overlay ****"
RUN S6_ARCH=$(case ${TARGETPLATFORM} in \
        "linux/amd64")    echo "amd64"    ;; \
        "linux/386")      echo "x86"      ;; \
        "linux/arm64")    echo "aarch64"  ;; \
        "linux/arm/v7")   echo "armhf"    ;; \
        "linux/arm/v6")   echo "arm"      ;; \
        "linux/ppc64le")  echo "ppc64le"  ;; \
        *)                echo ""         ;; esac) \
    && echo "s6 overlay platform selected "$S6_ARCH \
    && wget -q https://github.com/just-containers/s6-overlay/releases/latest/download/s6-overlay-${S6_ARCH}.tar.gz -qO /tmp/s6-overlay.tar.gz \
    && tar xfz /tmp/s6-overlay.tar.gz -C /s6/

FROM alpine:latest

LABEL maintainer="Alexander Zinchenko <alexander@zinchenko.com>"

ENV URL_NORDVPN_API="https://api.nordvpn.com/server" \
    URL_RECOMMENDED_SERVERS="https://nordvpn.com/wp-admin/admin-ajax.php?action=servers_recommendations" \
    URL_OVPN_FILES="https://downloads.nordcdn.com/configs/archives/servers/ovpn.zip" \
    PROTOCOL=openvpn_udp \
    MAX_LOAD=70 \
    RANDOM_TOP=0 \
    CHECK_CONNECTION_ATTEMPTS=5 \
    CHECK_CONNECTION_ATTEMPT_INTERVAL=10

RUN echo "**** upgrade packages ****" && \
    apk --no-cache --no-progress upgrade && \
    echo "**** install packages ****" && \
    apk --no-cache --no-progress add bash curl unzip iptables ip6tables jq openvpn && \
    echo "**** create folders ****" && \
    mkdir -p /vpn && \
    mkdir -p /ovpn && \
    echo "**** cleanup ****" && \
    rm -rf /tmp/* && \
    rm -rf /var/cache/apk/*

COPY --from=s6-builder /s6/ /
COPY root/ /

RUN chmod +x /app/*

VOLUME ["/config"]
VOLUME ["/data"]

WORKDIR  /config

ENTRYPOINT ["/init"]
