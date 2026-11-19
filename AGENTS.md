# Notes for coding agents

This is a public open-source repository.

## Layout

- `Sources/`, `ARFramework/`, `Plug-ins (AX)/`, `main.m` — the app (Objective-C); `*.lproj/` — localizations.
- `docs/` — the GitHub Pages site: `appcast.xml` (Sparkle feed) and `releasenotes/`.
- `scripts/release.sh`, `scripts/sparkle/` — release tooling; `RELEASING.md` — the release how-to.

## Conventions

When making changes here, **do not commit any private or sensitive information**, including but not limited to:

- Personal email addresses, real names of third parties, or contact details
- Apple Developer Team IDs, signing identities, or full provisioning details
- Notarization / app-specific passwords or any other credentials
- Sparkle EdDSA private keys (the public key in `Info.plist` is fine — it is meant to be public)
- Absolute paths from a developer's machine (`/Users/<name>/...`)
- Internal URLs, hostnames, or tokens

Public-by-design items that are okay to keep:
- The Sparkle public key (`SUPublicEDKey` in `Info.plist`)
- The GitHub repo URL and the GitHub Pages appcast URL
- The repository owner's GitHub handle (it is necessarily public)

If you find any of the above slipped into the working tree, flag it before committing. If something already landed in git history, prefer `git filter-repo --replace-text` over committing a redaction on top, since the original blob remains reachable until objects are pruned.

The old arizona-software.ch inside the app's in-app text, Help and credits is accepted legacy (the app is not
shipping); audits leave it. New text and URLs use jean-bovet.ch.

## Release

`scripts/release.sh` (steps in `RELEASING.md`). The release script reads `SIGN_ID` and `NOTARY_PROFILE` from the environment so the developer's identity never has to be hard-coded. Keep it that way.
