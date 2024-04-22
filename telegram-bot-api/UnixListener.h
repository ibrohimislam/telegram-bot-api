#pragma once

#include "td/actor/actor.h"

#include "td/utils/common.h"
#include "td/utils/port/ServerSocketFd.h"
#include "td/utils/port/SocketFd.h"
#include "td/utils/Slice.h"

namespace telegram_bot_api {

class UnixListener final : public td::Actor {
 public:
  class Callback : public td::Actor {
   public:
    virtual void accept(td::SocketFd fd) = 0;
  };

  UnixListener(td::string path, td::ActorShared<Callback> callback);
  void hangup() final;

 private:
  td::ServerSocketFd server_fd_;
  td::ActorShared<Callback> callback_;
  const td::string path_;
  void start_up() final;
  void tear_down() final;
  void loop() final;
};

}  // namespace td
