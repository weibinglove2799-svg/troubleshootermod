# -*- coding: utf-8 -*-
"""校验所有 MOD zip：内部文件与 Data 一致（除阈值/原版三件套），并列出 Mods 目录。"""
import hashlib
import io
import os
import re
import sys
import zipfile

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

root = r'D:\games\steam\steamapps\common\Troubleshooter'
data_dir = os.path.join(root, 'Data')
mods_dir = os.path.join(root, 'Mods')

files = [
    'script/server/battle.lua', 'script/server/buff.lua', 'script/server/lobby.lua',
    'script/server/lobby_enter.lua', 'script/server/mastery.lua',
    'script/shared/shared_ability.lua', 'script/shared/shared_mastery.lua',
    'xml/AbilityDirectingEvent.xml', 'xml/Buff.xml', 'xml/Mastery.xml',
]


def md5_bytes(b):
    return hashlib.md5(b).hexdigest()


data_md5 = {}
for rel in files:
    with open(os.path.join(data_dir, rel), 'rb') as f:
        data_md5[rel] = md5_bytes(f.read())

for zname in sorted(os.listdir(mods_dir)):
    if not zname.lower().endswith('.zip'):
        continue
    zp = os.path.join(mods_dir, zname)
    z = zipfile.ZipFile(zp)
    print('\n=== %s (%d entries) ===' % (zname, len(z.namelist())))
    for rel in files:
        content = z.read(rel)
        thr_match = None
        if rel == 'script/shared/shared_mastery.lua':
            m = re.search(rb'XZJF_SetMasteryMinCount\s*=\s*(\d+)', content)
            thr_match = m.group(1).decode() if m else 'N/A'
        same = md5_bytes(content) == data_md5[rel]
        flag = 'SYNC' if same else 'DIFF'
        if not same:
            # 输出差异原因：仅阈值替换 或 原版三件套
            if thr_match is not None and thr_match != 'N/A':
                flag += ' (threshold=%s)' % thr_match
            elif rel == 'script/shared/shared_mastery.lua':
                flag += ' (original shared_mastery)'
            elif rel in ('script/server/lobby.lua', 'script/server/lobby_enter.lua'):
                flag += ' (original lobby)'
        print('  %-38s %s' % (rel, flag))
