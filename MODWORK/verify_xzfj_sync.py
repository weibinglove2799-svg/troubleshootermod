# -*- coding: utf-8 -*-
import io, os, re, sys, zipfile
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

game_root = r'D:\games\steam\steamapps\common\Troubleshooter'
check_files = [
    (r'Mods\XZJF_Mod_K1.zip', 1),
    (r'Modsbackup\XZJF_Mod_K1.zip', 1),
    (r'Modsbackup\XZJF_Mod_K2.zip', 2),
    (r'Modsbackup\XZJF_Mod_K3.zip', 3),
    (r'Modsbackup\XZJF_Mod_K4.zip', 4),
]

# 需要在 zip 中出现的新逻辑片段
must_have = [
    ('script/server/mastery.lua', 'Xzfj_RevokeUnitBenefits'),
    ('script/server/mastery.lua', 'Xzfj_EnsureUnitBenefits'),
    ('script/server/mastery.lua', "if Xzfj_IsPlayerSideUnit(unit) then"),
    ('script/shared/shared_mastery.lua', '受控优先'),
    ('script/shared/shared_mastery.lua', "obj.IsUserMember or GetInstantProperty(obj, 'CUSTOM_USER_MEMBER')"),
    ('xml/Mastery.xml', 'Event="UnitTurnStart" Script="Mastery_Xianzhifanji_UnitTurnStart"'),
]
must_not_have = [
    ('script/server/mastery.lua', 'Event="UnitTurnStart_Self" Script="Mastery_Xianzhifanji_UnitTurnStart"'),
]

ok = True
for rel_zip, thr in check_files:
    p = os.path.join(game_root, rel_zip)
    with zipfile.ZipFile(p) as zf:
        sm = zf.read('script/shared/shared_mastery.lua').decode('utf-8')
        m = re.search(r'XZJF_SetMasteryMinCount\s*=\s*(\d+)', sm)
        cur = int(m.group(1)) if m else None
        print('=== %s  threshold=%s ===' % (rel_zip, cur))
        if cur != thr:
            print('  !! threshold mismatch, expected %s' % thr)
            ok = False
        for entry, frag in must_have:
            data = zf.read(entry).decode('utf-8', errors='replace')
            hit = frag in data
            if not hit:
                print('  !! MISSING in %s: %r' % (entry, frag))
            ok = ok and hit
        for entry, frag in must_not_have:
            data = zf.read(entry).decode('utf-8', errors='replace')
            if frag in data:
                print('  !! SHOULD NOT HAVE in %s: %r' % (entry, frag))
                ok = False

print('\n' + ('ALL OK' if ok else 'SOME CHECKS FAILED'))
