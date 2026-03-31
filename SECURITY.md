# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 0.3.x   | :white_check_mark: |
| < 0.3   | :x:                |

## Reporting a Vulnerability

If you discover a security vulnerability in TLX, please report it responsibly.

**Do not open a public GitHub issue for security vulnerabilities.**

### Preferred: GitHub Security Advisories

1. Go to the [Security Advisories](https://github.com/jrjsmrtn/tlx/security/advisories) page
2. Click "Report a vulnerability"
3. Fill in the details

### Alternative: Email

Send details to **jrjsmrtn@gmail.com** with subject line `[TLX Security]`.

Include:

- Description of the vulnerability
- Steps to reproduce
- Impact assessment (if known)
- Suggested fix (if any)

### What to expect

- Acknowledgement within 7 days
- Assessment and fix timeline within 30 days
- Credit in the advisory (unless you prefer anonymity)

## Scope

TLX is a development/test dependency — it does not run in production. Security concerns are primarily:

- **Supply chain**: compromised dependencies, tampered packages
- **Code execution**: mix tasks execute user-provided module names
- **Information disclosure**: emitted TLA+ files may contain design details

## Security Practices

- Dependencies audited via `mix_audit` (CVE scanning) and `mix hex.audit` (retired packages)
- Pre-commit hooks scan for leaked credentials (gitleaks)
- SPDX license headers on all source files
- Static analysis via Credo
- Type checking via Dialyzer
