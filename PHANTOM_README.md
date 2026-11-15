# Phantom economy mod — Telegram Desktop (Linux build here, Windows recipe)

Client-side visual mod: fake Stars/TON balance and "sent" gifts/NFT with **no
RPC** leaving the client. Nothing syncs; the server never sees a request.

## What was downloaded / built

| piece | source | state |
|---|---|---|
| tdesktop source | `github.com/telegramdesktop/tdesktop` dev `1924801` (7.4.2) | `/home/ramix/tdmod/tdesktop` |
| TDLib (tde2e only) | `github.com/tdlib/td` @ `c15d3f5a5` | built → `/home/ramix/tdmod/td/install` |
| wallet-engine | `github.com/i582/wallet-engine` v0.0.7 + desktop-app patch | built → `/home/ramix/tdmod/wallet-engine-0.0.7/install` |
| Qt6 / ffmpeg / openal / … | system (Arch) | used via `DESKTOP_APP_USE_PACKAGED=ON` |

## The patch

`phantom_economy.patch` (also applied in-tree):

- `SourceFiles/fake_economy.h` — env-driven fake values, local spend counter.
- `data/components/credits.cpp` — `balance()`, `tonBalance()`, `apply()` return
  the fake, so every screen (settings, profile, gift box) shows it consistently.
- `api/api_premium.{h,cpp}` — process-wide cache of raw `MTPStarGift` /
  `MTPStarGiftUnique` entries collected from the gift catalog, saved gifts and
  resale lists (`rawStarGift(id)`, `rawStarGiftUnique(id)`, `rememberStarGift`).
  It lives outside the per-provider `PremiumGiftCodeOptions` instance because
  the Stars gifts provider leaves `GiftsDescriptor::api` null.
- `data/data_star_gift.cpp` — feeds saved and resale unique gifts into that raw
  cache.
- `boxes/star_gift_box.cpp` — `SendGift()` short-circuits to
  `CheckoutResult::Paid` when enabled: success toast + chat opens + box closes,
  no `payments.sendStarsForm` is ever sent. For star gifts it also injects a
  real local `messageActionStarGift` service message into the chat, so the
  gift bubble actually appears in history. Fires the built-in
  `Ui::StartFireworks` animation (pure C++ particles, no external assets) on
  success. A phantom transfer skips the server price form and goes straight to
  the confirmation box.
- `boxes/transfer_gift_box.cpp` — `BuyResaleGift()` and `TransferGift()` resolve
  as `Paid` locally: no `payments.buyStarGift` / `payments.transferStarGift` is
  sent. When the raw unique gift is known, a local
  `messageActionStarGiftUnique` bubble is injected into the chat with the real
  owner (`peer`), a sane `transfer_stars` (`TD_FAKE_TRANSFER_STARS`, default 25)
  and the actual resale amount. Fireworks play on success too.
- `history/history_item.cpp` — for locally injected unique gift messages the
  parsed `UniqueGift::ownerId` is replaced with the actual recipient, so the
  gift info box shows the new owner instead of the previous reseller.
- `info/peer_gifts/info_peer_gifts_widget.cpp` +
  `info/profile/info_profile_values.cpp` — locally sent gifts are prepended to
  the recipient profile's Gifts tab and counted in the profile subtitle, so the
  phantom gift is visible in the person's profile without any server data.
- `boxes/star_gift_box.cpp` — `SendStarsFormRequest()` also short-circuits, so
  any star payment form (not just direct gift sends) is "paid".

Re-apply anywhere:

```bash
cd tdesktop && git apply ../phantom_economy.patch
```

## Build (Linux, the exact commands used here)

```bash
# 1. TDLib, e2e only (provides the tde2e package tdesktop links)
cd td && cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=None \
  -DCMAKE_INSTALL_PREFIX="$PWD/install" -DTD_E2E_ONLY=ON \
  && cmake --build build -j"$(nproc)" && cmake --install build

# 2. wallet-engine (needs rust 1.96.1 pinned by rust-toolchain.toml)
cd wallet-engine-0.0.7 && patch -Np1 -i ../wallet-engine.patch \
  && cargo build --release --locked && cargo xtask bindings cpp \
  && install -Dm644 target/release/libwallet_engine.a -t install/lib/ \
  && install -Dm644 bindings/cpp-experimental/* -t install/include/wallet_engine/

# 3. tdesktop
cd tdesktop && cmake -S . -B out -G Ninja -DCMAKE_BUILD_TYPE=Release \
  -DDESKTOP_APP_DISABLE_AUTOUPDATE=ON -DDESKTOP_APP_USE_PACKAGED=ON \
  -DDESKTOP_APP_USE_PACKAGED_FONTS=ON -DDESKTOP_APP_ENABLE_LTO=OFF \
  -Dtde2e_DIR="$PWD/../td/install/lib/cmake/tde2e" \
  -DCMAKE_PREFIX_PATH="$PWD/../wallet-engine-0.0.7/install" \
  -DTDESKTOP_API_ID=611335 -DTDESKTOP_API_HASH=d524b414d21f4d37f08684c1df41ac9c \
  && cmake --build out -j"$(nproc)"
```

Binary: `tdesktop/out/bin/Telegram`; the stripped copy is `/home/ramix/tdmod/Telegram-phantom-linux-x64`.

## Run

Infinite balance (the number never goes down):

```bash
TD_FAKE_ECONOMY=1 TD_FAKE_INFINITE=1 TD_FAKE_STARS=999999 TD_FAKE_TON=13370 \
  TD_FAKE_TRANSFER_STARS=25 ./Telegram-phantom-linux-x64
```

Spending balance (starts at your own value and ticks down per phantom send):

```bash
TD_FAKE_ECONOMY=1 TD_FAKE_STARS=500 TD_FAKE_TON=13370 \
  TD_FAKE_TRANSFER_STARS=25 ./Telegram-phantom-linux-x64
```

`TD_FAKE_STARS=inf` is an alias for infinite mode. Unset `TD_FAKE_ECONOMY` →
stock behaviour. `TD_FAKE_TRANSFER_STARS` only changes the price shown for
transferring a phantom unique gift (default 25).

Easiest: use `launcher/PhantomLauncher.sh` or `launcher/PhantomLauncher.bat`
instead of typing variables; the launcher stores them in `phantom.ini`.

## API credentials

`611335` / `d524b414d21f4d37f08684c1df41ac9c` are the public snap-build
credentials Arch uses. For your own client, register at
`https://my.telegram.org/apps` and reconfigure with your own id/hash.

## Launcher

`launcher/` holds ready-made launchers that set every variable for you and
remember the choice in `phantom.ini` next to the binary:

- **Windows:** `PhantomLauncher.bat` (opens `PhantomLauncher.ps1`, a small window
  with mode, Stars, TON, transfer price and the Telegram.exe path).
- **Linux:** `PhantomLauncher.sh` (zenity window, or terminal prompts without
  zenity).

Copy the launcher files next to `Telegram.exe` / `Telegram`, or point the
launcher at the binary. Both write the same `phantom.ini`.

## Windows

Two routes, both producing a portable folder with `Telegram.exe`,
`PhantomLauncher.bat` and `PhantomLauncher.ps1`.

### GitHub Actions (no Windows machine needed)

1. Fork/push this tree, put `phantom_economy.patch` in the repository root.
2. Copy `ci/phantom-windows.yml` to `.github/workflows/phantom-windows.yml`.
3. Run the **Phantom Windows Release** workflow.
4. Download the `Phantom-Telegram-Windows-x64` artifact.

The workflow mirrors the stock `win.yml` pipeline: prepare all libraries,
configure Release with the public API id/hash, build, then pack `out\Release`.

### Local MSVC 2022 build

From the **x64 Native Tools Command Prompt for VS 2022**:

```bat
powershell -NoProfile -ExecutionPolicy Bypass -File windows\build-win.ps1
```

It runs `Telegram\build\prepare\win.bat` (downloads Qt, TDLib, wallet-engine,
Rust and the rest), configures Release, builds and writes
`dist\Phantom-Telegram`. Needs VS 2022 C++ workload, Git, CMake, NuGet, Python
and internet access. Re-run with `-SkipPrepare` to reuse the libraries.

Manual fallback is the same three steps:

```bat
Telegram\build\prepare\win.bat skip-release silent
cd Telegram
configure.bat x64 -D TDESKTOP_API_ID=611335 ^
  -D TDESKTOP_API_HASH=d524b414d21f4d37f08684c1df41ac9c ^
  -D CMAKE_CONFIGURATION_TYPES=Release -D DESKTOP_APP_DISABLE_AUTOUPDATE=ON
cmake --build ..\out --config Release --parallel
```

The resulting `Telegram.exe` takes the same environment variables as Linux;
the launcher sets them.

## Limits (honest)

- The Linux binary in this folder is built and smoke-tested here. A Windows
  `.exe` cannot be compiled on this Linux machine (no MSVC/cross toolchain), so
  the Windows build is automated through `windows/build-win.ps1` or the GitHub
  Actions workflow in `ci/`. Neither has been run yet against this exact fork;
  the first run is the real test.
- Star gifts show a real gift bubble in chat (local service message built from
  the catalog's raw `MTPStarGift`).
- NFT/unique gifts show a chat bubble only if the client has already seen that
  exact `MTPStarGiftUnique` (resale tab / own saved gifts) during this run —
  then the raw entry is cached and a local `messageActionStarGiftUnique` is
  injected. Otherwise the purchase still resolves as `Paid` with the usual
  toast, just without a bubble.
- The phantom gift is listed in the recipient profile (Gifts tab) and counted
  in the subtitle. It is a local list entry: tapping it opens the normal gift
  box, but actions that need server ids (pin, collection, delete) may fail.
- Fireworks use the client's own `Ui::StartFireworks` particle animation; no
  external animation files are added, so the effect exists exactly where the
  stock build already supports it.
- Fake state is session-only: no sync, disappears on restart/relogin.
