//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2024
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "telegram-bot-api/UnixListener.h"

#include "td/utils/logging.h"
#include "td/utils/port/detail/PollableFd.h"

#if TD_PORT_POSIX
#include <cerrno>

#include <arpa/inet.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <unistd.h>
#endif

#if TD_PORT_WINDOWS
#include "td/utils/port/detail/Iocp.h"
#include "td/utils/port/Mutex.h"
#include "td/utils/VectorQueue.h"
#endif

namespace telegram_bot_api {

UnixListener::UnixListener(td::string path, td::ActorShared<Callback> callback)
    : path_(path), callback_(std::move(callback)) {
}

void UnixListener::hangup() {
  stop();
}

void UnixListener::start_up() {
  if (access(path_.c_str(), F_OK) == 0) {
    unlink(path_.c_str());
  }

  auto r_socket = td::ServerSocketFd::open(path_);
  if (r_socket.is_error()) {
    LOG(ERROR) << "Can't open server socket: " << r_socket.error();
    set_timeout_in(5);
    return;
  }
  server_fd_ = r_socket.move_as_ok();
  td::Scheduler::subscribe(server_fd_.get_poll_info().extract_pollable_fd(this));
}

void UnixListener::tear_down() {
  if (!server_fd_.empty()) {
    td::Scheduler::unsubscribe_before_close(server_fd_.get_poll_info().get_pollable_fd_ref());
    server_fd_.close();
    unlink(path_.c_str());
  }
}

void UnixListener::loop() {
  if (server_fd_.empty()) {
    start_up();
    if (server_fd_.empty()) {
      return;
    }
  }
  sync_with_poll(server_fd_);
  while (can_read_local(server_fd_)) {
    auto r_socket_fd = server_fd_.accept();
    if (r_socket_fd.is_error()) {
      if (r_socket_fd.error().code() != -1) {
        LOG(ERROR) << r_socket_fd.error();
      }
      continue;
    }
    send_closure(callback_, &Callback::accept, r_socket_fd.move_as_ok());
  }

  if (can_close_local(server_fd_)) {
    stop();
  }
}

}  // namespace td
