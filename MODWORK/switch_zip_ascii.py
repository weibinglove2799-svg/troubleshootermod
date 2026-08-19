import io
import os
import re
import shutil
import sys
import zipfile

from Crypto.Cipher import AES

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

root = r'D:\games\steam\steamapps\common\Troubleshooter'
IV_HEX = '86afc43868fea6abd40fbf6d5ed50905'
ZERO_KEY = bytes(16)
IV = bytes.fromhex(IV_HEX)


def decrypt(data):
    return AES.new(ZERO_KEY, AES.MODE_CBC, IV).decrypt(data)


def encrypt(data):
    pad = (16 - len(data) % 16) % 16
    if pad:
        data += bytes(pad)
    return AES.new(ZERO_KEY, AES.MODE_CBC, IV).encrypt(data)


def load_index(path):
    with open(path, 'rb') as f:
        data = f.read()
    dec = decrypt(data)
    if dec[:2] == b'PK':
        z = zipfile.ZipFile(io.BytesIO(dec))
        return z.read('index')
    return dec


# 1) 复制当前中文 zip 为英文名
src = os.path.join(root, 'Mods', '先制反击与单天赋解锁生效显示.zip')
dst = os.path.join(root, 'Mods', 'XZJF_Mod_K1.zip')
shutil.copy2(src, dst)
print('copied ->', dst)

# 2) 修改 index：把 pack 中的中文 zip 名改为英文
idx_path = os.path.join(root, 'Package', 'index')
text = load_index(idx_path).rstrip(b'\x00 ').decode('utf-8', 'replace')

new_text = text.replace(
    '../Mods/先制反击与单天赋解锁生效显示.zip',
    '../Mods/XZJF_Mod_K1.zip',
)
changed = text != new_text
print('index pack 替换:', changed)

if changed:
    # 保存前备份原 index
    bak = os.path.join(root, 'Package', 'index_xzfj_cn.bak')
    shutil.copy2(idx_path, bak)
    print('backup index ->', bak)

    # 保存新 index（加密）
    data = new_text.encode('utf-8')
    # 注意：原 index 保存时 TroubleTool 用了空字节填充而不是空格。我们保持原样长度对齐
    # 参考 IndexHelper: XmlDocument.Save -> 16字节对齐 -> 若 zipped 再包 zip
    # 但原 Package/index 解密后直接是 XML（非zip包裹），按 IndexHelper.LoadIndex，若解密后以 PK 开头则 zipped=true
    dec = decrypt(open(idx_path, 'rb').read())
    is_zipped = dec[:2] == b'PK'

    if is_zipped:
        # 重打包为 zip
        mem = io.BytesIO()
        with zipfile.ZipFile(mem, 'w', zipfile.ZIP_DEFLATED) as z:
            z.writestr('index', data)
        final = mem.getvalue()
    else:
        # 16 字节对齐填充空格（模仿 LoadIndex 的 \x00 -> ' ' 处理反向）
        final = data
        pad = (16 - len(final) % 16) % 16
        if pad:
            final += b'\x00' * pad
    enc = encrypt(final)
    with open(idx_path, 'wb') as f:
        f.write(enc)
    print('index 已更新并加密保存')

# 3) 验证重新读取
text2 = load_index(idx_path).rstrip(b'\x00 ').decode('utf-8', 'replace')
print('\n验证:')
print('  mod=true:', '<index mod="true">' in text2[:50])
print('  中文引用:', '../Mods/先制反击' in text2)
print('  英文引用:', '../Mods/XZJF_Mod_K1.zip' in text2)
mods_used = set(re.findall(r'\.\./Mods/([^"]+)', text2))
print('  引用 zip:', mods_used)
