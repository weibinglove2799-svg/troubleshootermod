# -*- coding: utf-8 -*-
"""校验所有 XZJF zip：新逻辑已进入（buff 并行调度 + shared_mastery 阵营判定 + abilitydirecter）。"""
import io
import os
import re
import sys
import zipfile

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

root = r'D:\games\steam\steamapps\common\Troubleshooter'
data_dir = os.path.join(root, 'Data')
mods_dir = os.path.join(root, 'Mods')


def load(*parts):
    with open(os.path.join(data_dir, *parts), 'rb') as f:
        return f.read()


data_buff = load('script', 'server', 'buff.lua')
data_sm = load('script', 'shared', 'shared_mastery.lua')
data_ad = load('script', 'client', 'abilitydirecter.lua')

for zname in sorted(os.listdir(mods_dir)):
    if not zname.lower().endswith('.zip'):
        continue
    zp = os.path.join(mods_dir, zname)
    z = zipfile.ZipFile(zp)
    names = z.namelist()
    buff = z.read('script/server/buff.lua')
    ad = z.read('script/client/abilitydirecter.lua')
    sm = z.read('script/shared/shared_mastery.lua')
    thr = re.search(rb'XZJF_SetMasteryMinCount\s*=\s*(\d+)', sm)
    print('===', zname)
    print('  has abilitydirecter          :', 'script/client/abilitydirecter.lua' in names)
    print('  buff has SubscribeFSMEvent   :', b'SubscribeFSMEvent' in buff)
    print('  buff has _overtake_ref       :', b'_overtake_ref' in buff)
    print('  buff matches Data            :', buff == data_buff)
    print('  ad matches Data              :', ad == data_ad)
    print("  sm has GetRelation faction   :", b"GetRelation, obj, 'player'" in sm)
    print('  threshold                    :', thr.group(1).decode() if thr else 'N/A')
