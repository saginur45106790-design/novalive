"""Static checks that protect common NovaLive V4 deployment mistakes."""
from pathlib import Path
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
main = (root / 'mobile/lib/main.dart').read_text()
guest = (root / 'mobile/lib/guest_shell.dart').read_text()
api = (root / 'mobile/lib/api.dart').read_text()
room = (root / 'mobile/lib/room_screen.dart').read_text()
server = (root / 'server/src.js').read_text()
assert 'GuestShell(api:api,onSignIn:_openAuth)' in main, 'Guest home route missing from main.dart'
assert "publicGet('/public/discover')" in guest, 'Public discovery API call missing'
assert 'Future<Map<String,dynamic>> publicGet' in api, 'Public GET API method missing'
assert 'guest:true' in guest and 'public:widget.guest' in room, 'Safe guest live-view path missing'
assert server.index("api.get('/public/discover'") < server.index('api.use(actor)'), 'Guest discovery route is after authentication middleware'
assert server.index("api.post('/public/rooms/:id/watch'") < server.index('api.use(actor)'), 'Guest watch route is private'
assert 'canPublish:false,canSubscribe:true,canPublishData:false' in server, 'Guest publish restrictions missing'
manifest = ET.parse(root / 'mobile/android/app/src/main/AndroidManifest.xml')
ns = '{http://schemas.android.com/apk/res/android}'
permissions = {p.attrib.get(ns+'name') for p in manifest.findall('uses-permission')}
required = {'android.permission.INTERNET','android.permission.CAMERA','android.permission.RECORD_AUDIO'}
assert required <= permissions, f'Android permissions missing: {required-permissions}'
print('PASS: Guest entry, public browse API, restricted live viewing, and Android source permissions present')
