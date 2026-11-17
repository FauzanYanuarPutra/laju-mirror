# Maintainer release checklist

Use this checklist before publishing a public LajuMirror installer.

## Build and CI

- [ ] Latest main branch CI completes successfully.
- [ ] Windows MSI installer is generated.
- [ ] Windows NSIS installer is generated.
- [ ] Packaged application includes scrcpy, ADB, the required DLLs/server file and third-party notices.
- [ ] Application icon is present in the executable and installer.
- [ ] No debug-only resource paths are required at runtime.
- [ ] Installer artifact can be installed and removed on a clean Windows 10 machine.
- [ ] Installer artifact can be installed and removed on a clean Windows 11 machine.

## USB device tests

- [ ] Xiaomi / HyperOS device is detected over a data USB cable.
- [ ] A fresh USB debugging authorization prompt appears and can be accepted.
- [ ] Authorized device is shown as Ready.
- [ ] Mirroring starts and stops.
- [ ] Mouse click, drag and keyboard input work.
- [ ] Fullscreen launch works.
- [ ] Audio remains on the Android-selected output device.
- [ ] Disconnecting and reconnecting USB recovers cleanly.
- [ ] Closing the mirroring window updates the app status.

## Wireless tests

- [ ] Android Wireless Debugging pairing works with a separate pairing port and code.
- [ ] Wireless Debugging connection uses the current connection port shown by Android.
- [ ] Wi-Fi mirroring works after USB cable removal.
- [ ] ADB TCP/IP mode works after the initial USB connection.
- [ ] Changed IP address or port can be entered again.
- [ ] Disconnecting the Wi-Fi device updates the device list.
- [ ] Wi-Fi connection failure gives an understandable message.

## Performance and UI

- [ ] 720p / 30 FPS / 4 Mbps works on a lower-end test device.
- [ ] 1080p / 60 FPS / 12 Mbps is measured on representative hardware.
- [ ] 1440p / 60 FPS / 20 Mbps is tested where the phone supports it.
- [ ] Long sessions do not leak child processes or leave stale status.
- [ ] Desktop UI works at 100%, 125% and 150% Windows display scaling.
- [ ] Window resizing and minimum window size remain usable.
- [ ] Indonesian and English copy are checked.
- [ ] Keyboard focus, contrast and screen-reader labels are reviewed.

## Security and release hygiene

- [ ] Review third-party licenses and notices for every bundled binary.
- [ ] Check the downloaded scrcpy release and its SHA-256 digest when available.
- [ ] Check application permissions and network behavior.
- [ ] Confirm Wireless Debugging is not exposed to public networks in demos.
- [ ] Review dependency update alerts.
- [ ] Update CHANGELOG.md and version fields.
- [ ] Create and push a version tag such as v0.1.0.
- [ ] Confirm the release workflow uploads MSI and EXE assets.
- [ ] Install the published release assets from GitHub Releases and repeat smoke tests.

## Public website

- [ ] Enable GitHub Pages with **GitHub Actions** as the build and deployment source.
- [ ] Confirm the published URL matches canonical and sitemap URLs.
- [ ] Confirm the landing page and 404 page load over HTTPS.
- [ ] Check mobile layout and language toggle.
- [ ] Validate page title, meta description, canonical URL and JSON-LD.
- [ ] Submit the sitemap to Google Search Console and Bing Webmaster Tools.
- [ ] Replace the GitHub Pages URL if a custom domain is configured.
- [ ] Add a custom domain and HTTPS only after DNS and Pages configuration are correct.

## Signing

The first builds may be unsigned. Before recommending broad distribution, consider acquiring a Windows code-signing certificate, signing the application and installer, and publishing a checksum file for each release.
