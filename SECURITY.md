# Security policy

## Supported versions

Security fixes are applied to the latest maintained version on the main branch. Pre-release builds may contain unresolved issues and should not be used for sensitive workflows.

## Reporting a vulnerability

Please do not disclose an unpatched vulnerability in a public issue.

Use GitHub's private vulnerability reporting feature for this repository when it is enabled. If private reporting is unavailable, contact the repository maintainer privately through the GitHub profile and include:

- A clear description of the issue.
- Reproduction steps and affected version or commit.
- Potential impact.
- A suggested mitigation, if known.

Do not include personal screen recordings, device serial numbers, pairing codes, passwords or unrelated private data.

## Security considerations

LajuMirror invokes ADB and scrcpy locally. Wireless ADB can grant debugging access to an authorized computer. Use trusted networks, verify Android authorization prompts, revoke unused authorizations and disable debugging when it is no longer needed.