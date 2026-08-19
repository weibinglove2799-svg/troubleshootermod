import zipfile
import os
import sys

sys.stdout = open(sys.stdout.fileno(), mode='w', encoding='utf-8', errors='replace')

game_root = r'D:\games\steam\steamapps\common\Troubleshooter'
modwork = os.path.join(game_root, 'MODWORK', 'Data')
out_zip = os.path.join(game_root, 'Mods', sys.argv[1])

# (MODWORK相对路径, zip条目路径)
files = [
    (r'script\server\battle.lua',          'script/server/battle.lua'),
    (r'script\server\buff.lua',            'script/server/buff.lua'),
    (r'script\server\lobby.lua',           'script/server/lobby.lua'),
    (r'script\server\lobby_enter.lua',     'script/server/lobby_enter.lua'),
    (r'script\server\mastery.lua',         'script/server/mastery.lua'),
    (r'script\shared\shared_ability.lua',  'script/shared/shared_ability.lua'),
    (r'script\shared\shared_mastery.lua',  'script/shared/shared_mastery.lua'),
    (r'xml\AbilityDirectingEvent.xml',     'xml/AbilityDirectingEvent.xml'),
    (r'xml\Buff.xml',                      'xml/Buff.xml'),
    (r'xml\Mastery.xml',                   'xml/Mastery.xml'),
]

missing = []
with zipfile.ZipFile(out_zip, 'w', zipfile.ZIP_DEFLATED) as zf:
    for rel, entry in files:
        src = os.path.join(modwork, rel)
        if not os.path.exists(src):
            missing.append(rel)
            continue
        zf.write(src, entry)

if missing:
    print('MISSING:', missing)
else:
    print('OK', out_zip)
    for rel, entry in files:
        print('  ', entry)
