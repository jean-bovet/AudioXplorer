# Notes for Claude

This is a public open-source repository.

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

Release tooling lives in `scripts/release.sh` and `scripts/sparkle/`. The release script reads `SIGN_ID` and `NOTARY_PROFILE` from the environment so the developer's identity never has to be hard-coded. Keep it that way.
