#!/usr/bin/env python3
"""Owner-only tool: make a Lifetime-Hints unlock code for ONE phone.

Usage:  python3 tools/make_code.py A1B2C-3D4E5
(The Device ID is what the buyer sends you on WhatsApp.)
Reads the secret from lib/data/services/hint_config.dart.
DO NOT ship this tool or your real secret to players.
"""
import hmac, hashlib, re, sys, pathlib

cfg = pathlib.Path(__file__).resolve().parent.parent / "lib/data/services/hint_config.dart"
secret = re.search(r"licenseSecret\s*=\s*'([^']+)'", cfg.read_text()).group(1)
if secret.startswith("CHANGE-ME"):
    sys.exit("Set a real licenseSecret in hint_config.dart first!")
if len(sys.argv) != 2:
    sys.exit(__doc__)
dev = re.sub(r"[^A-Z0-9]", "", sys.argv[1].upper())
mac = hmac.new(secret.encode(), f"MATHRA-LICENSE|{dev}".encode(), hashlib.sha256).hexdigest()[:12].upper()
print(f"{mac[:4]}-{mac[4:8]}-{mac[8:]}")
