# Third-party software notices

LajuMirror includes integration code that launches third-party Android debugging and screen mirroring tools. The Windows release workflow downloads the upstream Windows package at build time.

## scrcpy

- Project: https://github.com/Genymobile/scrcpy
- License: Apache License 2.0
- Copyright: scrcpy contributors
- Distribution: the official Windows release archive is included in packaged builds.

The scrcpy license is available at https://github.com/Genymobile/scrcpy/blob/master/LICENSE.

## Android Debug Bridge (ADB)

- Project and documentation: https://developer.android.com/tools/adb
- Distribution: ADB is included in the official Android platform tools bundled with the upstream scrcpy Windows package.
- License and notices: see the Android SDK platform-tools package and the Android Open Source Project license information at https://source.android.com/docs/setup/about/licenses.

## Other components

- Tauri: Apache-2.0 or MIT, https://tauri.app/
- React: MIT, https://github.com/facebook/react
- Vite: MIT, https://github.com/vitejs/vite
- lucide-react: ISC, https://github.com/lucide-icons/lucide

The licenses of these dependencies are not replaced by the LajuMirror MIT license. Users redistributing modified or bundled builds should preserve all applicable upstream notices.