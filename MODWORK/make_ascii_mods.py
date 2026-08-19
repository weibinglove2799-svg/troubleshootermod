# -*- coding: utf-8 -*-
"""生成 ASCII 文件名的 MOD zip（引擎窄字符文件 API 打不开中文 zip 名，已实测确认）。

输出规则（用户指定，2026-08-19）：
  Mods/            = 本地激活区，只输出当前正在使用的 K1（XZJF_Mod_K1.zip）
  Modsbackup/      = 本地备份区，输出 K1 K2 K3 K4 全部四个版本
  不再生成 LEGACY 或任何其他额外版本。

版本映射：
  XZJF_Mod_K1.zip  = 先制反击与单天赋解锁生效显示  (阈值1)
  XZJF_Mod_K2.zip  = 先制反击与双天赋解锁生效显示  (阈值2)
  XZJF_Mod_K3.zip  = 先制反击与三天赋解锁生效显示  (阈值3)
  XZJF_Mod_K4.zip  = 先制反击与四天赋解锁生效显示  (阈值4)

源文件统一取 Data 目录（与游戏实际加载一致）。
"""
import hashlib
import io
import os
import re
import sys
import zipfile

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

game_root = r'D:\games\steam\steamapps\common\Troubleshooter'
data_dir = os.path.join(game_root, 'Data')
mods_dir = os.path.join(game_root, 'Mods')
backup_dir = os.path.join(game_root, 'Modsbackup')

files = [
    (r'script\server\battle.lua',          'script/server/battle.lua'),
    (r'script\server\buff.lua',            'script/server/buff.lua'),
    (r'script\server\lobby.lua',           'script/server/lobby.lua'),
    (r'script\server\lobby_enter.lua',     'script/server/lobby_enter.lua'),
    (r'script\server\mastery.lua',         'script/server/mastery.lua'),
    (r'script\shared\shared_ability.lua',  'script/shared/shared_ability.lua'),
    (r'script\shared\shared_mastery.lua',  'script/shared/shared_mastery.lua'),
    (r'script\client\abilitydirecter.lua', 'script/client/abilitydirecter.lua'),
    (r'xml\AbilityDirectingEvent.xml',     'xml/AbilityDirectingEvent.xml'),
    (r'xml\Buff.xml',                      'xml/Buff.xml'),
    (r'xml\Mastery.xml',                   'xml/Mastery.xml'),
]

# 预读 Data 源文件（二进制，保持与游戏加载完全一致）
sources = {}
for rel, _ in files:
    p = os.path.join(data_dir, rel)
    with open(p, 'rb') as f:
        sources[rel] = f.read()


def replace_threshold(content_bytes, threshold):
    text = content_bytes.decode('utf-8')
    new, n = re.subn(
        r'(XZJF_SetMasteryMinCount\s*=\s*)\d+',
        r'\g<1>%d' % threshold,
        text,
    )
    if n != 1:
        raise RuntimeError('threshold replace failed, count=%d' % n)
    return new.encode('utf-8')


def write_zip(out_dir, name, content_map, expected_threshold=None):
    out = os.path.join(out_dir, name + '.zip')
    with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as zf:
        for rel, entry in files:
            zf.writestr(entry, content_map[rel])
    # 校验
    with zipfile.ZipFile(out) as zf:
        sm = zf.read('script/shared/shared_mastery.lua').decode('utf-8')
        m = re.search(r'XZJF_SetMasteryMinCount\s*=\s*(\d+)', sm)
        thr = int(m.group(1)) if m else None
    if expected_threshold is not None and thr != expected_threshold:
        raise RuntimeError('%s threshold mismatch: %s' % (name, thr))
    print('wrote %-28s threshold=%s' % (name + '.zip', thr))
    return out


# 1) 本地备份区 Modsbackup/：K1 K2 K3 K4 全部四个版本
for ascii_name, threshold in [
    ('XZJF_Mod_K1', 1),
    ('XZJF_Mod_K2', 2),
    ('XZJF_Mod_K3', 3),
    ('XZJF_Mod_K4', 4),
]:
    cmap = dict(sources)
    cmap[r'script\shared\shared_mastery.lua'] = replace_threshold(
        sources[r'script\shared\shared_mastery.lua'], threshold)
    write_zip(backup_dir, ascii_name, cmap, expected_threshold=threshold)

# 2) 本地激活区 Mods/：只输出当前正在使用的 K1
cmap = dict(sources)
cmap[r'script\shared\shared_mastery.lua'] = replace_threshold(
    sources[r'script\shared\shared_mastery.lua'], 1)
write_zip(mods_dir, 'XZJF_Mod_K1', cmap, expected_threshold=1)

print('\nALL DONE')
