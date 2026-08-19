import io
import os
import re
import sys
import zipfile

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

game_root = r'D:\games\steam\steamapps\common\Troubleshooter'
modwork = os.path.join(game_root, 'MODWORK', 'Data')
out_dir = os.path.join(game_root, 'Mods')

# 需要按阈值替换的文件（含 XZJF_SetMasteryMinCount 定义或引用，引用无需替换）
constant_file = r'script\shared\shared_mastery.lua'

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

# 版本名 -> 统一阈值
versions = [
    ('先制反击与单天赋解锁生效显示', 1),
    ('先制反击与双天赋解锁生效显示', 2),
    ('先制反击与三天赋解锁生效显示', 3),
    ('先制反击与四天赋解锁生效显示', 4),
]

# 预读源文件
sources = {}
missing = []
for rel, _ in files:
    p = os.path.join(modwork, rel)
    if not os.path.exists(p):
        missing.append(rel)
        continue
    with io.open(p, 'r', encoding='utf-8-sig', errors='replace') as f:
        sources[rel] = f.read()

if missing:
    print('MISSING SOURCES:', missing)
    sys.exit(1)

# 校验常量定义存在且当前为 1
m = re.search(r'XZJF_SetMasteryMinCount\s*=\s*(\d+)', sources[constant_file])
if not m:
    print('ERROR: XZJF_SetMasteryMinCount not found in', constant_file)
    sys.exit(1)
print('base threshold =', m.group(1))

for name, threshold in versions:
    out_zip = os.path.join(out_dir, name + '.zip')
    const_line = None
    with zipfile.ZipFile(out_zip, 'w', zipfile.ZIP_DEFLATED) as zf:
        for rel, entry in files:
            content = sources[rel]
            if rel == constant_file:
                content = re.sub(
                    r'XZJF_SetMasteryMinCount\s*=\s*\d+',
                    'XZJF_SetMasteryMinCount = %d' % threshold,
                    content,
                )
                const_line = re.search(r'XZJF_SetMasteryMinCount\s*=\s*\d+', content)
                if const_line is None:
                    print('ERROR: replace failed for', name)
                    sys.exit(1)
            zf.writestr(entry, content)
    print('OK', os.path.basename(out_zip), 'threshold =', threshold)
    print('  constant line:', const_line.group(0))
