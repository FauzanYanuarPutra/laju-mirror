# Windows Application Control and LajuMirror

This guide explains why Windows can block local builds and how to request a legitimate review.

## Why the local build is blocked

The reported error is:

~~~text
An Application Control policy has blocked this file. (os error 4551)
...src-tauri/target/debug/build/.../build-script-build.exe
~~~

This is not an Android permission prompt and it is not a normal UAC elevation issue.

Cargo compiles package build scripts into temporary executables and runs them while compiling Rust dependencies. The blocked names in the report (for example, proc-macro2, serde_core, and icu_normalizer_data) are dependency build scripts. Updating Rust or running PowerShell as administrator does not override an enforced application-control policy.

## What LajuMirror provides

Run the read-only helper from the repository root:

~~~powershell
.scriptswindows-diagnostics.ps1
~~~

It asks for explicit consent before collecting Windows version, development-tool versions, active policy information when available, and recent Code Integrity / AppLocker events. It saves a text report on the Desktop (or in the temporary folder).

If Windows denies access to event logs, the helper offers to relaunch itself with a standard UAC prompt. That elevation is only for reading diagnostics. It does not install, remove, or modify any policy and does not unblock executables.

To start the local development app with a confirmation and automatic diagnostics after a failed build:

~~~powershell
npm run dev:windows
~~~

## How to request administrator approval

Give the generated report to the administrator who manages the computer. Ask them to review:

- Code Integrity event 3077 for enforced App Control blocks.
- Code Integrity event 3076 for files that would be blocked under an audit policy.
- Correlated event 3089 for file-signature and publisher details.
- AppLocker MSI and Script events if the block comes from that rule collection.

The administrator should identify the active policy and choose a narrow, reviewed allow rule for the exact trusted software. Do not request a blanket exception for all executables under a user-writable folder or for all child processes of PowerShell, Node.js, Cargo, or rustc.

## Recommended path for everyday users

Most users should not need Rust, Cargo, Visual Studio Build Tools, or a local compiler. The preferred distribution path is a Windows installer built on the project's controlled GitHub Actions runner.

For devices enforcing Smart App Control or enterprise App Control, broad distribution may also require a trusted Authenticode code-signing certificate and, for managed devices, an administrator-approved publisher rule. A self-signed developer certificate is not a substitute for a trusted public code-signing identity.

Smart App Control does not provide an application-specific "allow this one anyway" confirmation for an arbitrary unsigned executable. It relies on Microsoft's reputation/intelligence checks and trusted signing. Enterprise App Control and AppLocker rules are controlled by the device administrator.

## What LajuMirror intentionally does not do

- It does not disable or weaken Windows security.
- It does not edit WDAC, App Control, Smart App Control, AppLocker, Defender, or registry policy values.
- It does not install a broad allow-list.
- It does not silently elevate the whole desktop app.
- It does not claim that clicking a LajuMirror confirmation can override Windows enforcement.

This is intentional. A user confirmation inside an application is not a valid security-policy decision by Windows.
