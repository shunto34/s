#!/usr/bin/env python3
import hashlib
import sys
from datetime import datetime

SECRET = "shunto_fx_2026"

def generate_key(year, month):
    src = f"{SECRET}{year:04d}{month:02d}"
    return hashlib.md5(src.encode()).hexdigest()[:8].upper()

if __name__ == "__main__":
    if len(sys.argv) == 3:
        y, m = int(sys.argv[1]), int(sys.argv[2])
    else:
        now = datetime.now()
        y, m = now.year, now.month

    key = generate_key(y, m)
    print(f"Year: {y}, Month: {m:02d}")
    print(f"License Key: {key}")
