#!/usr/bin/env python3
"""Generate manifest.json files for image galleries — API-style listing for static hosting.

Writes a [{name, size, mtime, is_dir}] manifest.json into each image directory
so galleries can discover images without the serve.py /api/list/ endpoint.
"""
import json
import os
from pathlib import Path

DIAGRAMS_DIR = Path(os.environ.get('DIAGRAMS_DIR', Path.home() / '.agent'))

IMAGE_DIRS = [
    'lyra/brand/concepts',
    'lyra/brand/concepts/avatar',
    'lyra/brand/concepts/avatar-v2',
]

for rel in IMAGE_DIRS:
    d = DIAGRAMS_DIR / rel
    if not d.is_dir():
        print(f'  skip {rel} (not found)')
        continue
    entries = sorted(
        [
            {
                'name': f.name,
                'size': f.stat().st_size,
                'mtime': int(f.stat().st_mtime),
                'is_dir': False,
            }
            for f in d.iterdir()
            if f.suffix == '.png'
        ],
        key=lambda x: x['name'],
    )
    manifest = d / 'manifest.json'
    manifest.write_text(json.dumps(entries, indent=2) + '\n')
    print(f'  {rel}/manifest.json: {len(entries)} images')
