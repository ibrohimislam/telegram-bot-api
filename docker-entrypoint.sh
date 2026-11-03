#!/bin/sh
set -e

USER_NAME=telegram-bot-api
DATA_DIR=${TELEGRAM_WORK_DIR:-/var/lib/telegram-bot-api}
SOCKET_PATH=${TELEGRAM_UNIX_SOCKET:-/run/telegram-bot-api/http.sock}
SOCKET_DIR=$(dirname "$SOCKET_PATH")

if [ "$(id -u)" = "0" ]; then
  # Mounted volumes keep their own ownership, so make them writable for the unprivileged user,
  # then drop privileges. Only recurse when the top directory has the wrong owner, to keep restarts fast.
  uid=$(id -u "$USER_NAME")
  mkdir -p "$DATA_DIR" "$SOCKET_DIR"
  if [ "$(stat -c %u "$DATA_DIR")" != "$uid" ]; then
    chown -R "$USER_NAME:$USER_NAME" "$DATA_DIR"
  fi
  chown "$USER_NAME:$USER_NAME" "$SOCKET_DIR"
  exec su-exec "$USER_NAME" "$0" "$@"
fi

# Environment variables supported for compatibility with other Bot API images
set -- "$@" --dir="$DATA_DIR" --unix-socket="$SOCKET_PATH"
[ -n "$TELEGRAM_LOCAL" ] && set -- "$@" --local
[ -n "$TELEGRAM_MAX_WEBHOOK_CONNECTIONS" ] && set -- "$@" --max-webhook-connections="$TELEGRAM_MAX_WEBHOOK_CONNECTIONS"
[ -n "$TELEGRAM_MAX_CONNECTIONS" ] && set -- "$@" --max-connections="$TELEGRAM_MAX_CONNECTIONS"
[ -n "$TELEGRAM_LOG_FILE" ] && set -- "$@" --log="$TELEGRAM_LOG_FILE"
[ -n "$TELEGRAM_VERBOSITY" ] && set -- "$@" --verbosity="$TELEGRAM_VERBOSITY"

exec telegram-bot-api "$@"
