# Windows Application Control and LajuMirror

This guide explains the confirmed local-build block and the supported ways to work around it without weakening Windows security.

## What the diagnostic report confirmed

The report from this development PC showed:

- Active enforced policy: `VerifiedAndReputableDesktop`.
- `VerifiedAndReputablePolicyState = 1`.
- Code Integrity event 3077 for Cargo-generated Rust dependency executables, including `serde_core`, `proc-macro2`, `thiserror`, `icu_normalizer_data`, and `icu_properties_data`.
- An earlier event 3077 for the native Rollup Node module.

This is consistent with Smart App Control enforcement. The block is not a normal UAC permission prompt. Cargo compiles package build scripts into temporary executables and runs them while building dependencies. The policy can block those unsigned temporary programs before the application itself is produced.

## Important limitation

LajuMirror cannot add itself to a Smart App Control allow-list, and there is no supported per-app "Allow anyway" button for Smart App Control. An application cannot grant itself a Windows Code Integrity exception through JavaScript, Rust, PowerShell, a UAC modal, or an installer.

Changing the app's source code alone cannot make Windows trust arbitrary unsigned build scripts. Do not disable Smart App Control, alter Code Integrity registry settings, install a broad allow rule, or whitelist an entire user-writable development folder.

## Recommended workflow for this PC

Use GitHub Actions as the Windows build machine. This avoids executing Rust dependency build scripts on the protected laptop.

1. Push the source changes to the `main` branch, or open the [LajuMirror CI workflow](https://github.com/FauzanYanuarPutra/laju-mirror/actions/workflows/ci.yml).
2. To start a build manually, open **Actions → CI → Run workflow**, select `main`, and run it.
3. Wait for the Windows job to finish successfully.
4. Open that workflow run and download the `lajumirror-windows-unsigned-preview` artifact only when you need to inspect build output.
5. Do not install this unsigned preview on a PC enforcing Smart App Control. Check `release-manifest.json` and `SHA256SUMS.txt`; a CI success does not establish publisher trust.
6. Install only a signed release from the [Releases page](https://github.com/FauzanYanuarPutra/laju-mirror/releases) after the project publishes one.

The CI workflow runs TypeScript checks, builds the frontend, prepares the pinned official scrcpy/ADB package, builds MSI and NSIS installers, checks Rust formatting and the Rust backend, and uploads the installer artifacts. Artifacts are retained for 14 days. The runtime download is pinned to scrcpy v5.0.1 and its reviewed Windows x64 archive SHA-256; bump the version and digest together only after reviewing the upstream release.

This is a remote build route, not a per-app Smart App Control exception. The installer must still satisfy Windows trust checks.

## Code signing

Smart App Control allows binaries it recognizes as safe or binaries signed with a code-signing certificate issued by a certificate authority in Microsoft's Trusted Root Program. The publisher certificate must be trusted by Windows. Self-signed development certificates do not provide public trust.

The Tauri bundle is configured to call `src-tauri/sign-windows-file.ps1` for its application executable. The release workflow also signs the MSI and NSIS installers. Unsigned bundled scrcpy/ADB EXE and DLL files are signed by the LajuMirror distributor identity using the same trusted certificate. The release workflow fails closed when trusted signing is not configured. Existing upstream signatures are preserved; an existing invalid signature is never overwritten. The binary manifest records each file's resulting signer and status.

Configure these GitHub Actions repository secrets:

- `WINDOWS_SIGNING_PFX_BASE64`: base64-encoded PFX containing the trusted code-signing certificate and private key.
- `WINDOWS_SIGNING_PFX_PASSWORD`: password for that PFX.

Add them under **GitHub repository → Settings → Secrets and variables → Actions**. Keep the private key out of the repository, source code, logs, and downloadable artifacts. The certificate must come from a provider trusted by Windows and be suitable for code signing.

Without both secrets, the CI preview deliberately completes an unsigned build and reports its signature state in the manifest. Public tagged releases are now blocked unless both secrets are present, the certificate chain is trusted on the Windows runner, and every distributed binary passes Authenticode verification. Signing the outer installer alone is not a guarantee: Windows can evaluate the app executable and bundled tools separately.

For public open-source projects, [SignPath Foundation](https://signpath.org/) offers free signing for projects that meet its eligibility and review conditions. LajuMirror has not been approved by that program. Its conditions include an already released, actively maintained project and signing only eligible project-owned binaries; upstream scrcpy/ADB binaries require separate attention.

## What gets recorded

The CI manifest records the SHA-256 hash and Authenticode status of the LajuMirror application executable, bundled runtime executables and DLLs, and generated MSI/NSIS installers. The manifest does not declare unsigned files trusted. Release verification also checks that every packaged runtime EXE/DLL, the LajuMirror app binary, and both installer formats are present in the manifest, hash-matched, and Authenticode-valid. Any unsigned or invalid binary blocks publication.

## Local UI work

The frontend-only Vite server can still be started with `npm run dev` for UI work. It does not provide the native Rust/ADB/scrcpy backend. Running `npm run tauri dev` still requires Cargo to execute its generated build scripts locally and may therefore be blocked by the active policy.

## Administrator-managed App Control

For Enterprise App Control or AppLocker, only the device administrator can deploy an appropriate narrow publisher or file rule. Give the administrator the diagnostic report and the exact file identity. Do not request a blanket exception for all executables under a writable folder or all child processes of PowerShell, Node.js, Cargo, or rustc.

## What LajuMirror intentionally does not do

- It does not disable or weaken Windows security.
- It does not edit WDAC, Smart App Control, AppLocker, Defender, or registry policy values.
- It does not install a broad allow-list.
- It does not silently elevate the entire desktop app.
- It does not claim that an application confirmation can override Windows enforcement.
