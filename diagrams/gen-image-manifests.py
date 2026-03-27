#!/usr/bin/env python3
"""Generate manifest.json files for image galleries — API-style listing for static hosting.

Writes a [{name, size, mtime, is_dir}] manifest.json into each image directory
so galleries can discover images without the serve.py /api/list/ endpoint.

Auto-discovers all directories under DIAGRAMS_DIR that contain .png files.
"""
import json
import os
from pathlib import Path

DIAGRAMS_DIR = Path(os.environ.get('DIAGRAMS_DIR', Path.home() / '.agent'))
SKIP = {'_dist', '__pycache__', '.git'}

for dirpath, dirnames, filenames in os.walk(DIAGRAMS_DIR):
    dirnames[:] = [d for d in dirnames if d not in SKIP]
    pngs = [f for f in filenames if f.endswith('.png')]
    if not pngs:
        continue
    d = Path(dirpath)
    entries = sorted(
        [
            {
                'name': f,
                'size': (d / f).stat().st_size,
                'mtime': int((d / f).stat().st_mtime),
                'is_dir': False,
            }
            for f in pngs
        ],
        key=lambda x: x['name'],
    )
    manifest = d / 'manifest.json'
    manifest.write_text(json.dumps(entries, indent=2) + '\n')
    rel = d.relative_to(DIAGRAMS_DIR)
    print(f'  {rel}/manifest.json: {len(entries)} images')
