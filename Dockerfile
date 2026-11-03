# syntax=docker/dockerfile:1

FROM alpine:3.20 AS build

RUN apk add --no-cache build-base cmake gperf linux-headers openssl-dev zlib-dev git

WORKDIR /src
# copy only what the build needs, so editing the entrypoint or compose file doesn't invalidate the compile cache
COPY CMakeLists.txt ./
COPY telegram-bot-api telegram-bot-api
COPY td td
RUN test -f td/CMakeLists.txt || \
    (echo "The td submodule is empty: run 'git submodule update --init --recursive' first" >&2; exit 1)

RUN mkdir /build && cd /build \
    && cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX:PATH=/install /src \
    && cmake --build . --target install -j"$(nproc)" \
    && strip /install/bin/telegram-bot-api

FROM alpine:3.20

# musl's malloc fragments badly under this workload, so preload jemalloc
RUN apk add --no-cache libstdc++ libssl3 libcrypto3 zlib jemalloc ca-certificates su-exec \
    && addgroup -S telegram-bot-api \
    && adduser -S -G telegram-bot-api -h /var/lib/telegram-bot-api telegram-bot-api \
    && mkdir -p /var/lib/telegram-bot-api /run/telegram-bot-api \
    && chown telegram-bot-api:telegram-bot-api /var/lib/telegram-bot-api /run/telegram-bot-api

COPY --from=build /install/bin/telegram-bot-api /usr/local/bin/telegram-bot-api
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENV LD_PRELOAD=/usr/lib/libjemalloc.so.2 \
    MALLOC_CONF=background_thread:true,dirty_decay_ms:5000,muzzy_decay_ms:0

# The entrypoint starts as root only to fix ownership of mounted volumes, then drops to the telegram-bot-api user.
VOLUME ["/var/lib/telegram-bot-api", "/run/telegram-bot-api"]

# TELEGRAM_API_ID and TELEGRAM_API_HASH must be provided in the environment
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
