# -*- coding: utf-8 -*-
"""重新打包 MODWORK 的所有 zip，源文件统一采用 Data 目录（与游戏实际加载一致）的最新版本。

修复背景：此前打包的 zip 内文件是旧版本，启用后游戏从 zip 加载旧版 Lua/XML，
导致 lobby 相关函数缺失、进基地界面错乱（酒吧NPC消失/任务栏错乱/主线不刷新）。

方案：
- 4 个「先制反击与X天赋解锁生效显示.zip」：Data 9 文件 + shared_mastery.lua 阈值=X
- 「先制反击.zip」（备用，无 Set Mastery 加速）：Data 版先制反击文件 + 原始版 lobby 三件套
- 「先制反击和单天赋解锁附加效果.zip」（备用）：Data 版 + shared_mastery.lua 阈值=1
"""
import io
import os
import re
import shutil
import sys
import zipfile

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

game_root = r'D:\games\steam\steamapps\common\Troubleshooter'
data_dir = os.path.join(game_root, 'Data')
mods_dir = os.path.join(game_root, 'Mods')
orig_dir = os.path.join(game_root, 'MODWORK', '_orig')
backup_dir = os.path.join(game_root, 'MODWORK', 'mods_backup_old')
os.makedirs(backup_dir, exist_ok=True)

# (Data相对路径, zip条目路径)
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

# 预读 Data 版源文件（二进制，保持与游戏加载完全一致）
sources = {}
for rel, _ in files:
    p = os.path.join(data_dir, rel)
    with open(p, 'rb') as f:
        sources[rel] = f.read()
    print('source %-40s %d bytes' % (rel, len(sources[rel])))

# 预读原始版 lobby 三件套（用于「先制反击.zip」）
def load(p):
    with open(p, 'rb') as f:
        return f.read()


orig_lobby = load(os.path.join(orig_dir, 'lobby.lua'))
orig_lobby_enter = load(os.path.join(orig_dir, 'lobby_enter.lua'))
orig_shared_mastery = load(os.path.join(orig_dir, 'shared_mastery.lua'))
print('original lobby.lua=%d lobby_enter.lua=%d shared_mastery.lua=%d' % (
    len(orig_lobby), len(orig_lobby_enter), len(orig_shared_mastery)))

# 备份旧 zip
for f in os.listdir(mods_dir):
    if f.lower().endswith('.zip'):
        src = os.path.join(mods_dir, f)
        dst = os.path.join(backup_dir, f)
        shutil.copy2(src, dst)
        print('backup old zip ->', f)


def replace_threshold(content_bytes, threshold):
    text = content_bytes.decode('utf-8')
    new, n = re.subn(
        r'(XZJF_SetMasteryMinCount\s*=\s*)\d+',
        r'\g<1>%d' % threshold,
        text,
    )
    if n != 1:
        raise RuntimeError('threshold replace failed for XZJF_SetMasteryMinCount, count=%d' % n)
    return new.encode('utf-8')


def write_zip(name, content_map):
    out = os.path.join(mods_dir, name + '.zip')
    with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as zf:
        for rel, entry in files:
            data = content_map[rel]
            zf.writestr(entry, data)
    print('wrote', name + '.zip')
    return out


# 1) 4 个统一阈值版本
for ver_name, threshold in [
    ('先制反击与单天赋解锁生效显示', 1),
    ('先制反击与双天赋解锁生效显示', 2),
    ('先制反击与三天赋解锁生效显示', 3),
    ('先制反击与四天赋解锁生效显示', 4),
]:
    cmap = dict(sources)
    cmap[r'script\shared\shared_mastery.lua'] = replace_threshold(sources[r'script\shared\shared_mastery.lua'], threshold)
    write_zip(ver_name, cmap)

# 2) 「先制反击.zip」：Data 版先制反击文件 + 原始版 lobby 三件套（无 Set Mastery 加速）
cmap = dict(sources)
cmap[r'script\server\lobby.lua'] = orig_lobby
cmap[r'script\server\lobby_enter.lua'] = orig_lobby_enter
cmap[r'script\shared\shared_mastery.lua'] = orig_shared_mastery
write_zip('先制反击', cmap)

# 3) 「先制反击和单天赋解锁附加效果.zip」：Data 版 + 阈值=1
cmap = dict(sources)
cmap[r'script\shared\shared_mastery.lua'] = replace_threshold(sources[r'script\shared\shared_mastery.lua'], 1)
write_zip('先制反击和单天赋解锁附加效果', cmap)

print('\nALL DONE')
