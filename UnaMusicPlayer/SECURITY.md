# Security Policy

## Reporting a vulnerability

Please do not report exploitable vulnerabilities in public issues. Use GitHub's private vulnerability reporting for this repository if enabled, or contact the repository maintainers privately through their GitHub profile.

Include the affected component, impact, reproduction steps and any relevant logs with secrets removed.

## Sensitive data

Never commit:
- API keys, Cloudflare tokens or account credentials.
- Music platform cookies, QR codes, QR session identifiers or bearer tokens.
- User library contents, personal data or production database exports.
- Private upstream endpoints or deployment secrets.

If a secret is committed, revoke or rotate it immediately. Removing it from a later commit does not make the exposed secret safe.

## Security expectations

- Keep TLS verification enabled.
- Validate provider and redirect URLs; do not create open proxies.
- Apply authentication, rate limiting and bounded request sizes to gateway routes. The current Worker enforces an API key, origin allowlist and bounded upstream response/time; production rate limiting and abuse monitoring still require Cloudflare-side configuration.
- Avoid logging authorization headers, cookies and query parameters containing credentials.
- Store client credentials in Keychain and server credentials in platform secret storage.
- Do not bypass DRM, subscription checks or provider access controls.
