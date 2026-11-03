# Security

## Reporting a vulnerability

Prefer GitHub's private **Report a vulnerability** form in the [Security tab](https://github.com/AdnanNaous/Ultimate-Windows-Maintenance/security/advisories/new) when it is enabled. If GitHub does not offer the form, do not post exploit details or sensitive files publicly. Ask the owner to enable private vulnerability reporting using a minimal issue without vulnerability details, then submit the private report.

Include the affected version/commit, impact, and minimal reproduction using synthetic data. Never include live credentials, private project files, personal notes or authentication logs. No response-time commitment is implied.

## Maintenance boundaries

Use the current default-branch revision or an explicitly reviewed release; older revisions are not promised security fixes. Dependency and automated scan results require review and do not prove safety. If a credential is exposed, treat it as potentially compromised and arrange rotation with the owner. Deleting a file or adding it to `.gitignore` does not remove Git history. Do not rewrite history or revoke access automatically.
