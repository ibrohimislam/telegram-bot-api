# syntax=docker/dockerfile:1

# jemalloc is built from source because Alpine's package is compiled without heap profiling.
FROM alpine:3.20 AS jemalloc

RUN apk add --no-cache build-base curl bzip2
ARG JEMALLOC_VERSION=5.3.0
RUN curl -fsSL -o /tmp/jemalloc.tar.bz2 \
      "https://github.com/jemalloc/jemalloc/releases/download/${JEMALLOC_VERSION}/jemalloc-${JEMALLOC_VERSION}.tar.bz2" \
    && tar -xjf /tmp/jemalloc.tar.bz2 -C /tmp \
    && cd /tmp/jemalloc-${JEMALLOC_VERSION} \
    && ./configure --prefix=/opt/jemalloc --enable-prof \
    && make -j"$(nproc)" build_lib_shared \
    && mkdir -p /opt/jemalloc/lib && cp lib/libjemalloc.so.2 /opt/jemalloc/lib/

FROM alpine:3.20 AS build

RUN apk add --no-cache build-base cmake gperf linux-headers openssl-dev zlib-dev git

WORKDIR /src
# copy only what the build needs, so editing the entrypoint or compose file doesn't invalidate the compile cache
COPY CMakeLists.txt ./
COPY telegram-bot-api telegram-bot-api
COPY td td
RUN test -f td/CMakeLists.txt || \
    (echo "The td submodule is empty: run 'git submodule update --init --recursive' first" >&2; exit 1)

# the binary is intentionally not stripped: jeprof needs the symbols to read the heap profiles
RUN mkdir /build && cd /build \
    && cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX:PATH=/install /src \
    && cmake --build . --target install -j"$(nproc)"

FROM alpine:3.20

RUN apk add --no-cache libstdc++ libssl3 libcrypto3 zlib ca-certificates su-exec \
    && addgroup -S telegram-bot-api \
    && adduser -S -G telegram-bot-api -h /var/lib/telegram-bot-api telegram-bot-api \
    && mkdir -p /var/lib/telegram-bot-api /run/telegram-bot-api \
    && chown telegram-bot-api:telegram-bot-api /var/lib/telegram-bot-api /run/telegram-bot-api

COPY --from=jemalloc /opt/jemalloc/lib/libjemalloc.so.2 /opt/jemalloc/lib/libjemalloc.so.2
COPY --from=build /install/bin/telegram-bot-api /usr/local/bin/telegram-bot-api
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# musl's malloc fragments badly under this workload, so preload jemalloc.
# Heap profiling is on: a sample every ~512 KiB allocated (lg_prof_sample:19) and a dump about every 16 GiB
# allocated (lg_prof_interval:34) into the data directory. Override MALLOC_CONF to change or disable it
# (e.g. drop prof:true).
# Analyze: copy jeprof.*.heap and /usr/local/bin/telegram-bot-api out of the container, then
#   jeprof --text telegram-bot-api jeprof.<pid>.<seq>.i<n>.heap
ENV LD_PRELOAD=/opt/jemalloc/lib/libjemalloc.so.2 \
    MALLOC_CONF=background_thread:true,dirty_decay_ms:5000,muzzy_decay_ms:0,prof:true,prof_active:true,lg_prof_sample:19,lg_prof_interval:34,prof_prefix:/var/lib/telegram-bot-api/jeprof

# The entrypoint starts as root only to fix ownership of mounted volumes, then drops to the telegram-bot-api user.
VOLUME ["/var/lib/telegram-bot-api", "/run/telegram-bot-api"]

# TELEGRAM_API_ID and TELEGRAM_API_HASH must be provided in the environment
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
