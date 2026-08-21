# Telegram Bot API on Unix Socket

The Telegram Bot API provides an HTTP API for creating [Telegram Bots](https://core.telegram.org/bots).

If you've got any questions about bots or would like to report an issue with your bot, kindly contact us at [@BotSupport](https://t.me/BotSupport) in Telegram.

Please note that only global Bot API issues that affect all bots are suitable for this repository.

## Table of Contents
- [Installation](#installation)
- [Dependencies](#dependencies)
- [Usage](#usage)
- [License](#license)

<a name="installation"></a>
## Installation

In general, you need to install all `Telegram Bot API server` dependencies and compile the source code using CMake:

```sh
git clone --recursive https://github.com/ibrohimislam/telegram-bot-api.git
cd telegram-bot-api
mkdir build
cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
cmake --build . --target install
```

<a name="dependencies"></a>
## Dependencies
To build and run `Telegram Bot API server` you will need:

* OpenSSL
* zlib
* C++17 compatible compiler (e.g., Clang 5.0+, GCC 7.0+, MSVC 19.1+ (Visual Studio 2017.7+), Intel C++ Compiler 19+) (build only)
* gperf (build only)
* CMake (3.10+, build only)

<a name="usage"></a>
## Usage

specify the unix domain socket location such i.e. `./telegram-bot-api.sock` using `--unix-socket` param:

```sh
./telegram-bot-api -v 5 --api-id=$API_ID --api-hash=$API_HASH --unix-socket=./telegram-bot-api.sock --local
```

to check the unix socket use curl with `--unix-socket` param:

```sh
curl --unix-socket ./telegram-bot-api.sock http://localhost/bot$BOT_TOKEN/getMe
```

in NodeJS [undici](https://github.com/nodejs/undici) you can set the agent parameter:
```js
import { fetch, Agent } from 'undici'

const BOT_TOKEN = "dummy-bot-token"
const resp = await fetch(`http://localhost/bot${BOT_TOKEN}/getMe`, {
  dispatcher: new Agent({
    connect: {
      socketPath: './telegram-bot-api.sock'
    }
  })
})

console.log(await resp.json())
```

<a name="license"></a>
## License
`Telegram Bot API server` source code is licensed under the terms of the Boost Software License. See [LICENSE_1_0.txt](http://www.boost.org/LICENSE_1_0.txt) for more information.
