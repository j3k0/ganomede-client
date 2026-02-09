# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Ganomede client library — a cross-platform SDK written in **Haxe** that compiles to JavaScript (Node.js/browser) and ActionScript 3 (Flash/AIR). It provides a unified API for interacting with Ganomede game server services (users, games, invitations, notifications, chat, virtual currency, etc.).

## Build Commands

The Haxe compiler is invoked via a local `./haxe` wrapper that runs inside a Docker image (source: `github.com:j3k0/docker-haxe`). Build targets are defined in the Makefile:

- `make js` — compile Haxe to JavaScript (`bin/ganomede.js`)
- `make as3` — generate ActionScript 3 source (`bin/ganomede-as3/`)
- `make swc` — build SWC library for Flash/AIR (`bin/ganomede.swc`)
- `make ajaxweb` — browserified + uglified Ajax web build (`bin/ajaxweb.min.js`)
- `make clean` — remove `bin/` directory

## Testing

Tests are integration tests that run against a live Ganomede server:

```bash
GANOMEDE_TEST_SERVER_URL=http://... \
GANOMEDE_TEST_USERNAME=... \
GANOMEDE_TEST_PASSWORD=... \
npm test
```

The test suite is in `src-js/test.js` (plain Node.js, no test framework). It requires `make js` to have been run first since it imports `bin/ganomede.js` via `index.js`. There is no unit test suite or way to run a single test in isolation.

## Architecture

### Compilation & Entry Points

Haxe source in `src/` compiles to multiple targets. For JavaScript, `index.js` loads the compiled `bin/ganomede.js` and re-exports `fovea.ganomede` as the public API, adding a `createClient(url, options)` factory function.

### Class Hierarchy

```
Ajax (src/fovea/net/Ajax.hx)              — HTTP client with platform adapters (#if flash / #elseif js)
  └─ ApiClient (ganomede/ApiClient.hx)    — adds response caching and request deduplication
       └─ GanomedeClient                  — single-server entry point, conditionally creates modules based on options
       └─ UserClient                      — base for authenticated per-user API modules
            └─ GanomedeUsers, GanomedeGames, GanomedeInvitations, GanomedeNotifications, ...
```

- **Ganomede** (`Ganomede.hx`) — top-level facade that manages a `GanomedeClientsPool` of `GanomedeClient` instances. Delegates to a single client after `initialize()`.
- **GanomedeClient** (`GanomedeClient.hx`) — instantiates only the modules enabled via `options.{module}.enabled`. Initialization runs all module inits in parallel.
- **UserClient** (`UserClient.hx`) — provides `executeAuth()` for token-based authenticated requests and a client factory pattern for per-user API access.

### Async Model

Custom Promise/Deferred implementation in `src/fovea/async/`:
- `Promise` — interface with `then()`, `error()`, `always()`, `invert()`
- `Deferred` — concrete implementation (PENDING → RESOLVED | REJECTED), supports `abort()`
- `Parallel` / `Waterfall` — combinators for concurrent and sequential async flows

### Service Modules

Each module (Users, Games, Invitations, Notifications, TurnGames, Avatars, Chats, VirtualCurrency, Statistics, Data, Challenges) follows the same pattern: extends `UserClient`, exposes CRUD-style methods returning `Promise`, and uses data models from `src/fovea/ganomede/models/`.

### Platform Abstraction

`Ajax.hx` uses Haxe conditional compilation (`#if flash` / `#elseif js`) to switch between OpenFL's `URLLoader` (Flash/AIR) and Node.js `http`/`https` modules. Auto-retries on 502/503/504 errors.

### Export Convention

All public API classes use the `@:expose` Haxe annotation to ensure they are accessible from JavaScript after compilation.

## Key Directories

- `src/fovea/ganomede/` — core client modules
- `src/fovea/ganomede/models/` — data model classes (GanomedeUser, GanomedeGame, etc.)
- `src/fovea/ganomede/helpers/` — higher-level helpers (TurnGameInvitation, TurnGameMover)
- `src/fovea/async/` — Promise/Deferred async utilities
- `src/fovea/net/` — Ajax HTTP abstraction
- `src-js/` — JavaScript test and browser wrapper code
- `src-as3/` — ActionScript 3 source
- `airpackage/` — AIR package definition for distribution
