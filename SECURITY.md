# Security Policy

## Supported versions

| Version | Supported |
|---------|-----------|
| 1.0.x   | Yes       |

## Report a vulnerability

Do not open a public issue for a security problem.

Use the **Report a vulnerability** button in the
[Security tab](https://github.com/Diamond9k/cloak/security/advisories/new)
of this repository. The report stays private until a fix is released.

Include:

- The Cloak version and the macOS version
- The steps to reproduce the problem
- The effect (for example: command execution, file deletion, wrong audit result)

## Scope

- The Cloak macOS app in this repository
- The shell commands that Cloak runs (Homebrew installs, system audit checks)
- The Cleanup feature (cache and log removal, metadata strip)
- The build script (`build.sh`)

Out of scope: vulnerabilities in the third-party tools that Cloak helps you
install. Report those to the maintainers of each tool.

## Response

- Acknowledgement: in 72 hours
- First assessment: in 7 days
- A fix or a mitigation plan follows the assessment. Credit is given in the
  release notes if you want it.
