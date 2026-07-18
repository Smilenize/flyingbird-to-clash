# Security Policy

## Sensitive data

Exported Clash / mihomo profiles contain usable connection credentials. Never attach any of the following to a public Issue or Pull Request:

- decrypted or encrypted YAML profiles
- subscription URLs or tokens
- node passwords, UUIDs, certificates, or private keys
- FlyingBird databases or AppData archives
- WebDAV credentials or public share links

If sensitive data is exposed, revoke or rotate the affected credential before reporting the problem.

## Reporting a vulnerability

Open a GitHub Issue only when the report contains no secrets. For a report that cannot be safely anonymized, use GitHub's private vulnerability reporting feature if it is enabled for this repository.

## Scope

This project reads files from the current Windows user's FlyingBird data directories and writes backups plus decrypted output to a user-selected directory. Review the output path and protect the exported files appropriately.
