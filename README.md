# netbanking — native macOS login for Sparkasse mk business e-banking

**What is this for?** Sparkasse Bank Macedonia's business internet banking
([netbanking.mk/Stopanstvo](https://www.netbanking.mk/Stopanstvo/Account/Login),
Asseco iBank) cannot be accessed from macOS: its login requires the
**"Aseba Crypto Signer"**, a Windows-only native component distributed as an
`.msi` (plus a retired Java-applet fallback). If you only use a Mac, that meant
keeping a Windows VM (Parallels) just for the bank.

This project replaces that missing signer with a **native macOS implementation**:
the portal runs in a small self-contained browser window, and every signing
operation goes straight to your **USB certificate token** (Gemalto IDPrime MD /
SafeNet eToken, used by the KIBS qualified-certificate infrastructure).

## How it works

1. The login page presents a one-time challenge (`TextToSign`, a GUID).
2. The app signs it with the private key on the token and POSTs
   `Certificate` (base64 DER of your qualified certificate) +
   `Signature` (base64 of **SHA1withRSA** over the challenge) to
   `/Stopanstvo/Account/LoginSmartCard` — byte-compatible with what the
   retired Java applet (`PKCS11Signer`) produced. *(The page's JavaScript asks
   the signer for SHA-256, but the server still verifies SHA-1 — confirmed
   against the decompiled 2014 applet.)*
3. The server answers with a JSON handshake (`UserAuthenticated`, session key,
   redirect) and you land on the Dashboard.
4. The **PIN is used only locally** to unlock the token — it is never sent to
   the bank (exactly like the original signer/applet).

The gem: no Java, no Windows, no browser extension. The app injects the
`TokenSigning` JS API the portal calls and implements it natively, so all
signing screens (login, payment orders) route to the USB token.

## Requirements

- macOS 13+
- A USB smart-card reader with the bank's token (~Gemalto reader + IDPrime MD
  or SafeNet eToken)
- **SafeNet Authentication Client** middleware installed
  (`/usr/local/lib/libeTPkcs11.dylib` etc.) — same drivers the bank asks for
- [Homebrew](https://brew.sh) with `brew install opensc` (provides
  `pkcs11-tool`, used for the token's always-authenticate signing path)

## Build & install

```bash
# CLI helper (python stdlib + python-pkcs11)
python3 -m venv venv && venv/bin/pip install -r requirements.txt

# Test that the token signs on macOS (prompts for PIN; completely offline)
./venv/bin/python netbank_login.py --test

# Headless login against the real portal (prints the authenticated URL)
./venv/bin/python netbank_login.py --login

# The GUI app
cd app && ./build.sh            # → NetBanking.app
open NetBanking.app             # enter PIN once, then log in as usual

# Installer package (installs the app to /Applications)
# produced at dist/NetBanking-1.0.pkg by the same build.sh
```

### The token cannot be read by the app?

The IDPrime key is flagged *always-authenticate* — it must get a
context-specific login right before each signature. In-process PKCS#11 clients
often fail this, so everything goes through `pkcs11-tool`, which handles it
correctly. Both the app and the CLI shell out to it on purpose.

## Troubleshooting

| Symptom | Cause |
|---|---|
| Portal shows "install Java" page | The bank serves a legacy page to Safari-like user agents; the app sends a Chrome UA. A plain browser on macOS cannot work — use the app. |
| `UserNotLoggedIn` from python-pkcs11 | Always-authenticate key; use `pkcs11-tool` (this repo does). |
| Card refuses `SHA1-RSA-PKCS` signing | Verify-only on newer IDPrime cards; the CLI builds the SHA-1 DigestInfo and signs with raw `RSA-PKCS` instead. |
| Server returns the full HTML shell instead of the JSON login handshake | A `Function` field was sent; the verified server contract has none. |
| Token error / blocked | PIN attempts: after 3 wrong PINs the token locks; contact corporate support (corporatenetbanking@sparkasse.mk, +389 46 261-000). |

## Security notes

- The PIN is prompted once per app launch and kept in memory only.
- Your private key never leaves the token; only challenge signatures do.
- This talks only to `www.netbanking.mk` over TLS.

## Disclaimer

Personal utility, not affiliated with or endorsed by Sparkasse Bank Macedonia,
Asseco SEE, KIBS AD Skopje, or any bank. The bank officially supports business
e-banking via the S-Banka mobile app (S-Token) and Windows signers — if you can
enroll in those, prefer them. Use at your own risk.