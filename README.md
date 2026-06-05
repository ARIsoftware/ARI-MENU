# ARI Menu

ARI Menu is a completely optional macOS native menu bar app to manage [ARI.Software](https://ari.software). It is free and open source. You can use it to easily start ARI, check the status, view the logs - all from the little circle in your menu bar.

<p align="center">
  <img src="docs/menu.jpg" alt="ARI Menu open in the macOS menu bar showing a green status indicator and Start/Stop controls" width="360" />
</p>

---

## Features

- **Start / Stop** — wraps `./ari start` and `./ari stop` from the ARI CLI
- **Live status indicator** — colored menu bar icon reflects whether the dev server is reachable (polls every 5 seconds by default)
- **Open ARI in browser** — one click opens `http://localhost:3000`
- **Live logs window** — tail dev server output in a SwiftUI window with copy and clear
- **Launch at login** — toggle from the menu, uses the modern `SMAppService` API (no LaunchAgent plists)
- **No Dock icon** — `LSUIElement` enabled; the app lives exclusively in the menu bar

The compiled `.app` bundle is around 400 KB and consumes negligible memory.

## Requirements

- macOS 13 (Ventura) or later
- Swift 5.9+ toolchain (ships with Xcode 15 or the standalone Command Line Tools — `xcode-select --install`)
- A working [ARI](https://github.com/ARIsoftware/ARI) checkout somewhere on disk (default location: `~/ARI`)

## Install

Visit [https://ari.software/docs/menu-app](https://ari.software/docs/menu-app) for installation instructions.

## How it works

ARI Menu is a thin SwiftUI shell over the existing `ari` CLI. It does not reimplement any ARI functionality — every action shells out to the CLI you already have:

- **Start** — spawns `/bin/zsh -lc 'cd <ARI_PATH> && ./ari start --verbose'`, streaming stdout and stderr to `~/Library/Logs/ARIMenu/ari.log`.
- **Stop** — sends `SIGTERM` to any process owning port 3000 (handles both menu-app-spawned and externally-launched dev servers), then runs `./ari stop` to tear down Supabase or Postgres as configured.
- **Status** — opens a TCP connection to `localhost:3000` (tries both IPv4 and IPv6, since `pnpm dev -H localhost` binds IPv6-only on macOS).
- **Logs** — tails the log file using `DispatchSource.makeFileSystemObjectSource` for live updates.
- **Launch at login** — uses `SMAppService.mainApp.register()`, the Apple-recommended API as of macOS 13.

The full source is in `Sources/ARIMenu/` — nine small Swift files, roughly 800 lines total.

## Repository layout

```
ARI-MENU/
├── Package.swift              # SwiftPM executable target (macOS 13+)
├── Sources/ARIMenu/           # Application source (~800 lines across 9 files)
├── Scripts/build-app.sh       # Compiles and assembles ARIMenu.app
├── LICENSE                    # Apache 2.0
└── README.md
```

## License

[Apache License 2.0](LICENSE). See the LICENSE file for the full text.

## Related

- [ARI.Software](https://github.com/ARIsoftware/ARI) — the upstream personal ops platform this menu app controls.
