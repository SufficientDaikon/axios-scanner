# Axios Attack Scanner - Claude Code Prompt

## How to use

1. Install Claude Code if you don't have it: `npm i -g @anthropic-ai/claude-code`
2. Open any terminal
3. Type `claude` and press Enter
4. Copy everything between the two lines below and paste it in
5. Press Enter and let it run

---

Scan my system for the axios supply chain attack from March 31 2026. The attacker hijacked the axios npm maintainer account and published malicious versions axios@1.14.1 and axios@0.30.4. These pulled in a package called "plain-crypto-js" that ran a postinstall script downloading a RAT (Remote Access Trojan) from sfrclak.com:8000/6202033.

Check ALL of these and report results:

1. Find every axios installation on my system (node_modules, npm/bun/npx caches, global). Flag versions 1.14.1 or 0.30.4.
2. Search everywhere for the "plain-crypto-js" package and for any setup.js inside axios directories.
3. Check for RAT files: %PROGRAMDATA%\wt.exe, %TEMP%\6202033.vbs, %TEMP%\6202033.ps1 (Windows) or /tmp/6202033.* (Linux/Mac).
4. Check DNS cache, hosts file, and active network connections for sfrclak.com or 142.11.206.73.
5. Check scheduled tasks, startup folder, and registry Run keys for anything with 6202033, plain-crypto, or sfrclak.
6. Scan all package-lock.json/yarn.lock/pnpm-lock.yaml for references to the bad versions.
7. If compromised: delete the malicious files and clean npm cache.
8. Write me a clear report: CLEAN or COMPROMISED, what you checked, what you found.

IOCs: axios@1.14.1 (SHA1: 2553649f2322049666871cea80a5d0d6adc700ca), axios@0.30.4 (SHA1: d6f3f62fd3b9f5432f5782b62d8cfd5247d5ee71), plain-crypto-js@4.2.1 (SHA1: 07d889e2dadce6f3910dcbc253317d28ca61c766), C2: sfrclak.com / 142.11.206.73:8000, endpoint: /6202033.

Go fully autonomous. Do not stop until every check is done.

---

That's it. It will scan your system and tell you if you're safe.
