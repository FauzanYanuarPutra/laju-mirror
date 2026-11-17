# Changelog

All notable changes to LajuMirror are documented here.

This project is in early development. Version 0.1.0 is an initial implementation, not a production-stability promise.

## [0.1.0] - Unreleased

### Added

- Windows desktop shell built with Tauri 2, React and TypeScript.
- Android device discovery through ADB.
- USB mirroring through scrcpy.
- Wireless Debugging pairing and connection workflow.
- ADB TCP/IP workflow initiated over USB.
- Default no-audio-forwarding behavior.
- Resolution, frame-rate and bitrate presets.
- Optional fullscreen launch.
- Mirroring process tracking and cleanup.
- Indonesian and English desktop interface.
- Indonesian setup, Wi-Fi, performance, privacy, FAQ and troubleshooting guides.
- Bilingual project landing page with search metadata, Open Graph metadata, sitemap, robots.txt and SoftwareApplication / FAQ structured data.
- Windows CI and installer release workflows.
- Issue templates and contribution/security guidance.

### Notes

- Installer publication depends on successful Windows GitHub Actions builds.
- USB and Wi-Fi behavior still needs hands-on validation across Android versions and device manufacturers.
- Only Windows 10/11 64-bit is targeted by the first milestone.
