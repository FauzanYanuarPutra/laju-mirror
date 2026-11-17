# Contributing to LajuMirror

Thanks for helping improve LajuMirror. Bug reports, documentation fixes, accessibility feedback and code contributions are welcome.

## Before opening an issue

1. Search existing issues to avoid duplicates.
2. Use the bug report or feature request template.
3. Include reproducible steps and the environment details requested by the template.
4. Remove personal information, device identifiers, pairing codes and private network details.

## Development setup

Requirements:

- Windows 10/11 64-bit for the currently supported desktop target.
- Node.js 20+ and npm.
- Stable Rust toolchain.
- Microsoft C++ Build Tools.
- WebView2 Runtime.

Clone the repository and install dependencies:

~~~powershell
git clone https://github.com/FauzanYanuarPutra/laju-mirror.git
cd laju-mirror
npm install
npm run tauri dev
~~~

For local mirroring, install the official scrcpy Windows package and place its files in src-tauri/resources/tools/scrcpy, or make scrcpy.exe and adb.exe available through PATH.

## Checks

Run these before submitting a pull request:

~~~powershell
npm run check
npm run build
cargo fmt --manifest-path src-tauri/Cargo.toml -- --check
cargo check --manifest-path src-tauri/Cargo.toml
~~~

## Pull request guidelines

- Keep changes focused and explain the user-facing reason.
- Preserve the default no-audio-forwarding behavior unless a separately reviewed feature explicitly changes it.
- Validate external input before passing it to ADB.
- Never pass user input through a shell command string. Use argument arrays.
- Update the relevant documentation when behavior or setup changes.
- Do not commit downloaded third-party binaries or secrets.
- Include screenshots for meaningful UI changes.

## Code of conduct

Be respectful, constructive and welcoming. Harassment, discrimination and personal attacks are not acceptable.