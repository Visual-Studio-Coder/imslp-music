#!/usr/bin/env python3
"""Copy named test screenshots out of an xcresult attachment export."""
import json
import pathlib
import shutil
import sys
source = pathlib.Path(sys.argv[1])
destination = pathlib.Path(sys.argv[2])
destination.mkdir(parents=True, exist_ok=True)
for test in json.loads((source / 'manifest.json').read_text()):
    for item in test['attachments']:
        name = item['exportedFileName']
        if name.endswith('.png') and not item['isAssociatedWithFailure']:
            label = item['suggestedHumanReadableName'].split('_0_')[0]
            shutil.copy2(source / name, destination / (label + '.png'))
