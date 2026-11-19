# LajuMirror

[![Windows CI](https://github.com/FauzanYanuarPutra/laju-mirror/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/FauzanYanuarPutra/laju-mirror/actions/workflows/ci.yml)
[![Latest release](https://img.shields.io/github/v/release/FauzanYanuarPutra/laju-mirror?display_name=tag)](https://github.com/FauzanYanuarPutra/laju-mirror/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

**Mirror and control your Android phone on Windows. Keep sound on your phone.**

Project website: https://fauzanyanuarputra.github.io/laju-mirror/

LajuMirror is a lightweight Windows desktop companion for mirroring and controlling Android devices over USB or Wi-Fi. It wraps the proven [scrcpy](https://github.com/Genymobile/scrcpy) engine in a friendly interface, so everyday users do not need to remember terminal commands.

> **Project status:** early development. USB and Wi-Fi workflows are being implemented. Prebuilt installers will be published in GitHub Releases after the Windows CI build and device testing are verified.

## What it aims to do

- Mirror Android screens over USB.
- Connect over Wi-Fi using Android Wireless Debugging pairing or classic ADB TCP/IP.
- Keep audio on the phone by default. Audio forwarding to the computer is disabled.
- Control the phone with the computer's mouse and keyboard.
- Choose video size, bitrate and frame-rate presets.
- Detect connected devices and show actionable connection status.
- Offer Indonesian and English help for setup and troubleshooting.

## Download and remote Windows build

The MSI/EXE CI preview is unsigned and must not be installed on PCs enforcing Smart App Control. The Windows CI now also builds a separate **unsigned MSIX submission package** for the Microsoft Store. Microsoft re-signs MSIX packages after Store certification; this avoids requiring LajuMirror to embed a private code-signing certificate in the repository. The MSIX artifact is not installable or Store-ready until the exact package identity and publisher from Partner Center are configured. See [Microsoft Store distribution](docs/MICROSOFT-STORE.md).

The CI workflow also supports manual runs: open **Actions → CI → Run workflow**, choose the `main` branch, and start the Windows build. A successful CI run proves that the application compiles and the MSIX package can be staged. It does not mean the package has been approved or signed by Microsoft.

For direct GitHub Releases distribution outside the Store, a trusted Authenticode certificate is still required. The release workflow fails closed unless the configured certificate is valid and every distributed executable, DLL and installer passes signature and SHA-256 verification. Do not install unsigned MSI/EXE previews or weaken Windows security.

The CI workflow's **Run workflow** form accepts the three exact package identity values from Partner Center. It also verifies the MSIX contents against source hashes and runs ADB/scrcpy startup checks from the packaged runtime folder. This is a packaging/runtime smoke test, not Microsoft Store certification or a physical Android device test.

LajuMirror currently targets **Windows 10/11, 64-bit**. An Android phone with USB debugging or Wireless Debugging enabled is required.

## Quick start

For a guided Windows setup, clone the repository and launch the control panel with one command:

~~~powershell
git clone https://github.com/FauzanYanuarPutra/laju-mirror.git
cd laju-mirror
git pull --ff-only
powershell -NoProfile -ExecutionPolicy Bypass -File .\laju.ps1 -Mode Gui
~~~

The LajuMirror control panel checks prerequisites, requests consent before downloading the official ADB/scrcpy tools, and offers one-click local development or unsigned local preview builds. If Smart App Control is enforcing policy, the GUI still opens, but local run/build actions are disabled. Use **Microsoft Store Setup** in the panel to open the developer registration page and the Partner Center setup guide. The current unsigned CI artifacts are packaging outputs only; do not install them on a PC enforcing Smart App Control. The Store MSIX becomes installable only after its exact Partner Center identity is configured, the app passes Store certification, and Microsoft publishes the Store-signed package. The launcher never disables Windows security or silently requests Administrator access. Android USB debugging and Wireless Debugging approval still have to be granted directly on the phone.

1. Install LajuMirror from a verified GitHub Release.
2. On your Android phone, open **Settings → About phone** and tap **Build number / OS version** repeatedly until Developer options are enabled. The exact label varies by phone.
3. Open **Settings → Additional settings / System → Developer options** and enable **USB debugging**.
4. Connect the phone with a data-capable USB cable and accept the debugging authorization prompt on the phone.
5. Open LajuMirror, select the online device, keep **Phone audio** enabled, choose a quality preset and select **Start mirroring**.

For the complete walkthrough, see [USB setup](docs/USB.md), [Wi-Fi setup](docs/WIFI.md), and [Troubleshooting](docs/TROUBLESHOOTING.md).

## Wi-Fi connection

Two methods are supported:

- **Android Wireless Debugging (recommended):** pair LajuMirror with the pairing address and code shown in Developer options → Wireless debugging. Then connect using the separate IP address and port shown by Android.
- **ADB TCP/IP:** connect once over USB, enable TCP/IP on the phone, then connect to the phone's local IP address and port (usually 5555).

Use Wi-Fi only on a trusted private network. Android may change the phone's IP address or debugging port after reconnecting. See [Wi-Fi setup](docs/WIFI.md).

## Audio behavior

LajuMirror starts scrcpy with audio forwarding disabled (the `--no-audio` option). This is designed for the use case where the phone remains the audio output device while the laptop displays the screen. It does not promise to route laptop system audio back to the phone, and it does not change the phone's own volume or media-output selection.

## Build from source

Requirements:

- Windows 10/11 64-bit
- Node.js 20 or newer and npm
- Rust stable toolchain
- Microsoft C++ Build Tools with the desktop C++ workload
- WebView2 Runtime (normally present on current Windows 10/11 installations)

~~~powershell
git clone https://github.com/FauzanYanuarPutra/laju-mirror.git
cd laju-mirror
npm install
npm run dev
~~~

`npm run dev` starts the frontend only. It is useful for UI work but does not provide the native Rust, ADB, or scrcpy backend.

To run the full desktop development app on a machine that allows local Rust builds:

~~~powershell
npm run dev:windows
~~~

On a device enforcing Smart App Control, local Cargo builds may be blocked because Cargo runs generated dependency build scripts. Do not try to grant the app an exception through code or weaken Windows security. Use the [remote Windows CI build](docs/WINDOWS-APP-CONTROL.md) instead. The installer signature status is recorded in `release-manifest.json`.

~~~powershell
npm run check
cargo fmt --manifest-path src-tauri/Cargo.toml -- --check
cargo check --manifest-path src-tauri/Cargo.toml
npm run tauri icon src-tauri/icons/icon.svg
npm run tauri build
~~~

## Documentation

- [Installation and first connection](docs/GETTING_STARTED.md)
- [USB connection](docs/USB.md)
- [Wi-Fi connection](docs/WIFI.md)
- [Quality and performance](docs/PERFORMANCE.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Windows Application Control and remote builds](docs/WINDOWS-APP-CONTROL.md)
- [Privacy and security](docs/PRIVACY.md)
- [FAQ](docs/FAQ.md)
- [Release checklist for maintainers](docs/RELEASE-CHECKLIST.md)
- [Changelog](CHANGELOG.md)
- [Contributing](CONTRIBUTING.md)
- [Code of conduct](CODE_OF_CONDUCT.md)
- [Security policy](SECURITY.md)

## Privacy

LajuMirror is designed to run locally. Device discovery, ADB commands and mirroring are performed on your computer. The app does not need a LajuMirror account, cloud relay or upload of your screen. See [Privacy and security](docs/PRIVACY.md) for details and the limitations of Android debugging over a network.

## Third-party software and licenses

LajuMirror's interface and integration code are licensed under MIT. It uses the separately maintained [scrcpy](https://github.com/Genymobile/scrcpy) project and Android Debug Bridge (ADB) tools. Their licenses and notices remain applicable; see [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md). LajuMirror is not affiliated with Google, Xiaomi, or the scrcpy maintainers.

## Help and feedback

Found a bug or have an idea? Please read [CONTRIBUTING.md](CONTRIBUTING.md), then open a [GitHub issue](https://github.com/FauzanYanuarPutra/laju-mirror/issues).

---

Made for a wider screen, without moving your phone's sound.
