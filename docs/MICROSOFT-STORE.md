# Microsoft Store distribution for LajuMirror

## Why this path exists

The current GitHub MSI and NSIS previews are unsigned. Smart App Control blocks unsigned or untrusted executable code on protected Windows 11 devices. Do not install those previews or weaken Windows security to force them to run.

LajuMirror now has a separate MSIX packaging path. The MSIX package contains the LajuMirror executable, the complete \`resources/tools/scrcpy\` runtime, ADB, all bundled DLLs, and third-party notices. The package is deliberately left unsigned for Store submission. Microsoft applies its own trusted package signature after the submission passes Store certification.

This is different from publishing the existing MSI or EXE installer. Microsoft does not re-sign MSI or EXE installers submitted to the Store; the MSIX route is the route that provides Store-managed signing.

## What is already automated

The Windows CI workflow now:

1. Builds the Tauri application and official pinned scrcpy/ADB runtime.
2. Stages the application executable and all runtime files into an MSIX layout.
3. Generates Store tile assets from the LajuMirror application icon.
4. Builds an unsigned MSIX package using Microsoft's WinApp CLI.
5. Opens the package and verifies that the executable, ADB, scrcpy, DLL resources, manifest, and Store assets are present.
6. Writes \`store-msix-metadata.json\` with the package identity, SHA-256 digest, and whether a real Partner Center identity was supplied.

The artifact is named \`lajumirror-windows-store-msix\`. The existing \`lajumirror-windows-unsigned-preview\` artifact remains for MSI/EXE build diagnostics only.

## One-time Partner Center setup

A Microsoft Store developer account is required before the package can be submitted. Microsoft currently offers a no-registration-fee onboarding flow in nearly 200 markets. Account identity verification is still required.

1. Open [Microsoft Store developer registration](https://storedeveloper.microsoft.com/).
2. Sign in with the Microsoft account that will own the LajuMirror Store listing.
3. Choose the correct account type. Individual accounts are for independent developers publishing outside a business, trade, or profession. Company accounts require a legal business entity and verification. Microsoft does not support converting an individual account into a company account later.
4. Complete the identity and MFA checks.
5. In Partner Center, create a new app and reserve the name **LajuMirror**.
6. Open the app's product identity details and copy the exact **Package/Identity Name**, **Publisher**, and **Publisher Display Name** values. Do not guess these values from the LajuMirror GitHub username or application identifier.

## Configure the repository

Open GitHub → \`FauzanYanuarPutra/laju-mirror\` → Settings → Secrets and variables → Actions → Variables.

Create these repository variables (they are package metadata, not private keys):

| Variable | Value |
|---|---|
| \`LAJUMIRROR_STORE_IDENTITY_NAME\` | Exact Package/Identity Name from Partner Center |
| \`LAJUMIRROR_STORE_PUBLISHER\` | Exact Publisher distinguished name from Partner Center |
| \`LAJUMIRROR_STORE_PUBLISHER_DISPLAY_NAME\` | Exact Publisher Display Name from Partner Center |

Do not put passwords, certificates, private keys, or personal identity documents in these variables or in the repository.

## Build and submit

1. Open [Actions → CI](https://github.com/FauzanYanuarPutra/laju-mirror/actions/workflows/ci.yml).
2. Run the workflow on \`main\`.
3. Wait for the Windows job to finish successfully.
4. Download the \`lajumirror-windows-store-msix\` artifact.
5. Open \`store-msix-metadata.json\` and confirm \`storeSubmissionReady\` is \`true\`. If it is \`false\`, the package was built with a preview identity and must not be submitted.
6. Upload the \`.msix\` package in Partner Center for the reserved LajuMirror app.
7. Complete Store listing fields, privacy information, screenshots, age rating, and certification checks.
8. Publish after Microsoft approves the submission.

The package must not be installed directly before Store signing. An unsigned MSIX package is a submission input, not an installer for the protected laptop. Once Microsoft signs and publishes the app, install LajuMirror from its Microsoft Store listing.

## Limits and expectations

- A successful CI run validates compilation and MSIX packaging. It does not mean Microsoft has approved the app.
- Store certification is a separate review and may request changes to the app, listing, privacy description, or capabilities.
- The package uses the \`runFullTrust\` capability because LajuMirror is a desktop app that starts local ADB and scrcpy processes. This capability must be declared accurately in the Store submission.
- The MSIX package is x64 in this pipeline. ARM64 packaging is not enabled yet.
- The traditional MSI/EXE distribution path remains available only after a trusted Authenticode certificate is configured and all distributed PE files pass signature verification.
