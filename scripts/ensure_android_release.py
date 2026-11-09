#!/usr/bin/env python3
"""Apply and verify required permissions *after* flutter create, before release build.
No external Python packages required.
"""
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

MANIFEST = Path(sys.argv[1] if len(sys.argv) > 1 else
                'mobile/android/app/src/main/AndroidManifest.xml')
ANDROID = 'http://schemas.android.com/apk/res/android'
ET.register_namespace('android', ANDROID)
perms = [
    'android.permission.INTERNET',
    'android.permission.ACCESS_NETWORK_STATE',
    'android.permission.CAMERA',
    'android.permission.RECORD_AUDIO',
    'android.permission.MODIFY_AUDIO_SETTINGS',
]
if not MANIFEST.is_file():
    raise SystemExit('AndroidManifest.xml missing: ' + str(MANIFEST))
root = ET.parse(MANIFEST).getroot()
if root.tag != 'manifest':
    raise SystemExit('Invalid manifest root')
key = '{%s}name' % ANDROID
existing = {el.get(key) for el in root.findall('uses-permission')}
for name in perms:
    if name not in existing:
        entry = ET.Element('uses-permission', {key: name})
        root.insert(0, entry)
app = root.find('application')
if app is None:
    raise SystemExit('Missing Android application element')
app.set('{%s}label' % ANDROID, 'NovaLive')
app.set('{%s}usesCleartextTraffic' % ANDROID, 'false')
app.set('{%s}icon' % ANDROID, '@mipmap/ic_launcher')
# Leave native camera optional on devices without a rear camera.
feature_key = '{%s}name' % ANDROID
if not any(el.get(feature_key) == 'android.hardware.camera' for el in root.findall('uses-feature')):
    root.insert(0, ET.Element('uses-feature', {
        feature_key: 'android.hardware.camera',
        '{%s}required' % ANDROID: 'false',
    }))
ET.indent(root, space='    ')
ET.ElementTree(root).write(MANIFEST, encoding='unicode', xml_declaration=True)
# Parse again and fail loudly, so the CI can never silently ship without permission.
parsed = ET.parse(MANIFEST).getroot()
actual = {el.get(key) for el in parsed.findall('uses-permission')}
missing = set(perms) - actual
if missing:
    raise SystemExit('Missing Android permissions: ' + ', '.join(sorted(missing)))
print('Verified release manifest:', MANIFEST)
for item in perms:
    print('  OK', item)
