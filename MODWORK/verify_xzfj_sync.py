# -*- coding: utf-8 -*-
"""校验所有 XZJF zip：新逻辑已进入（buff 并行调度 + shared_mastery 阵营判定 + abilitydirecter + Tima 兜底）。"""
import io
import os
import re
import sys
import zipfile

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

root = r'D:\games\steam\steamapps\common\Troubleshooter'
data_dir = os.path.join(root, 'Data')
mods_dirs = [os.path.join(root, 'Mods'), os.path.join(root, 'Modsbackup')]


def load(*parts):
    with open(os.path.join(data_dir, *parts), 'rb') as f:
        return f.read()


data_buff = load('script', 'server', 'buff.lua')
data_sm = load('script', 'shared', 'shared_mastery.lua')
data_ad = load('script', 'client', 'abilitydirecter.lua')
data_mas = load('script', 'server', 'mastery.lua')

for mods_dir in mods_dirs:
    print('########## DIR:', mods_dir)
    for zname in sorted(os.listdir(mods_dir)):
        if not zname.lower().endswith('.zip'):
            continue
        zp = os.path.join(mods_dir, zname)
        z = zipfile.ZipFile(zp)
        names = z.namelist()
        buff = z.read('script/server/buff.lua')
        ad = z.read('script/client/abilitydirecter.lua')
        sm = z.read('script/shared/shared_mastery.lua')
        mas = z.read('script/server/mastery.lua')
        thr = re.search(rb'XZJF_SetMasteryMinCount\s*=\s*(\d+)', sm)
        print('===', zname)
        print('  has abilitydirecter          :', 'script/client/abilitydirecter.lua' in names)
        print('  buff has SubscribeFSMEvent   :', b'SubscribeFSMEvent' in buff)
        print('  buff has _overtake_ref       :', b'_overtake_ref' in buff)
        print('  buff has Preemptive guard    :', b"eventArg, 'DirectingConfig', 'Preemptive'" in buff)
        print('  buff no alreadyHitSet        :', b'XzfjForestallTargets' not in buff)
        print('  buff matches Data            :', buff == data_buff)
        print('  ad matches Data              :', ad == data_ad)
        print('  mas has Tamer fallback       :', b'unit.Tamer' in mas and b'IsPlayerTeam' in mas)
        print('  mas no target-set reset      :', b'XzfjForestallTargets' not in mas)
        print('  mas matches Data             :', mas == data_mas)
        print('  sm has Xzfj_IsPlayerSideUnit :', b'Xzfj_IsPlayerSideUnit' in sm)
        print('  sm has Tamer fallback        :', b'obj.Tamer' in sm)
        print('  sm matches Data              :', sm == data_sm)
        print('  threshold                    :', thr.group(1).decode() if thr else 'N/A')

