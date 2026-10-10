#!/usr/bin/env python3
"""Prepare private TH15 1.00b resources. Never executes the Windows game."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import struct

ROOT = Path(__file__).resolve().parents[2]

def crypt(src, key, step, block, limit):
    out = bytearray(src); size = len(src)
    untouched = (size % block if size % block < block // 4 else 0) + (size & 1)
    remaining = size - untouched; cursor = 0
    while remaining > 0 and limit > 0:
        count = min(block, remaining); linear = 0
        for parity in (1, 2):
            for pos in range(count - parity, -1, -2):
                out[cursor + pos] = src[cursor + linear] ^ key
                key = (key + step) & 255; linear += 1
        cursor += count; remaining -= count; limit -= count
    return out

def decode(src, capacity):
    cursor = available = buf = 0; dictionary = bytearray(8192); head = 1; out = bytearray()
    def bits(n):
        nonlocal cursor, available, buf
        while available < n:
            # The original encoder omits a partial all-zero terminator.
            if cursor >= len(src) + 3: raise ValueError('Truncated compressed archive')
            buf = (buf << 8) | (src[cursor] if cursor < len(src) else 0)
            cursor += 1; available += 8
        available -= n; buf &= (1 << (available + n)) - 1
        return (buf >> available) & ((1 << n) - 1)
    def put(value):
        nonlocal head
        if len(out) >= capacity: raise ValueError('Compressed entry exceeds declared size')
        out.append(value); dictionary[head] = value; head = (head + 1) & 8191
    while True:
        if bits(1): put(bits(8))
        else:
            offset = bits(13)
            if not offset: break
            for n in range(bits(4) + 3): put(dictionary[(offset + n) & 8191])
    if len(out) != capacity: raise ValueError('Compressed entry size mismatch')
    return out

def music_layout(archive):
    data = archive.read_bytes(); header = crypt(data[:16], 27, 55, 16, 16)
    if header[:4] != b'THA1': raise ValueError('Expected TH15 THA1 archive')
    raw, packed, count = struct.unpack_from('<III', header, 4)
    raw = (raw - 123456789) & 0xffffffff; packed = (packed - 987654321) & 0xffffffff
    count = (count - 135792468) & 0xffffffff
    if packed > len(data) or raw > 64 * 1024 * 1024 or count > 100000: raise ValueError('Invalid archive table')
    end = len(data) - packed; table = decode(crypt(data[end:], 62, 155, 128, packed), raw)
    cursor = 0; entries = []
    for _ in range(count):
        start = cursor; cursor = table.index(0, start); name = table[start:cursor].decode('shift_jis')
        cursor = start + ((cursor - start + 4) & ~3)
        offset, size, _ = struct.unpack_from('<III', table, cursor); cursor += 12
        entries.append((name, offset, size))
    ciphers = [(27,115,256,14336),(18,67,512,15872),(53,121,1024,15360),(3,145,128,25600),(171,220,128,28672),(81,158,256,16384),(193,21,1024,11264),(153,125,128,17408)]
    for i, (name, offset, size) in enumerate(entries):
        if name != 'thbgm.fmt': continue
        stop = entries[i + 1][1] if i + 1 < len(entries) else end
        if not 16 <= offset <= stop <= end: raise ValueError('Invalid music entry')
        payload = crypt(data[offset:stop], *ciphers[sum(name.encode('shift_jis')) & 7])
        return decode(payload, size) if len(payload) != size else payload
    raise ValueError('Music layout missing in th15.dat')

def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()

def convert_music(original, layout, out):
    import numpy as np
    import soundfile as sf
    out.mkdir(parents=True, exist_ok=True); rows = []
    with original.open('rb') as source:
        if source.read(4) != b'ZWAV': raise ValueError('Expected original ZWAV music container')
        for at in range(0, len(layout) - 51, 52):
            if not layout[at]: break
            name, offset, length, intro, end = struct.unpack_from('<16sIIII', layout, at)
            name = name.split(b'\0')[0].decode('ascii')
            fmt = struct.unpack_from('<HHIIHH', layout, at + 32)
            if fmt != (1,2,44100,176400,4,16) or not 0 <= intro < end <= length or intro % 4 or end % 4: raise ValueError('Invalid PCM layout')
            source.seek(offset); pcm = source.read(end)
            if len(pcm) != end: raise ValueError('Truncated original PCM')
            samples = np.frombuffer(pcm, dtype='<i2').reshape(-1, 2); path = out / (Path(name).stem + '.ogg')
            with sf.SoundFile(str(path), 'w', samplerate=44100, channels=2, subtype='VORBIS', format='OGG', compression_level=.4) as target:
                for start in range(0, len(samples), 16384): target.write(samples[start:start+16384].astype(np.float32)/32768.)
            decoded, rate = sf.read(str(path), dtype='int16', always_2d=True)
            if decoded.shape != samples.shape or rate != 44100: raise ValueError('Vorbis sample count mismatch')
            rows.append(dict(filename=name, offset=offset, length=end, intro=intro, rate=44100, channels=2, align=4, frames=len(samples), loopFrame=intro//4, bytes=path.stat().st_size, sha256=sha(path), originalPcmSha256=hashlib.sha256(pcm).hexdigest(), decodedBytes=decoded.size*2))
            print(f'{len(rows)}/18 {name}: sample count verified', flush=True)
    if len(rows) != 18: raise ValueError('Missing music tracks')
    report = dict(kind='th15-original-pcm-vorbis-conversion', layoutSha256=hashlib.sha256(layout).hexdigest(), sourceBytes=original.stat().st_size, codec='Vorbis compression_level 0.4; lossy audio, exact sample count and loop positions', tracks=rows)
    (out/'manifest.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--original', required=True, type=Path)
    parser.add_argument('--fonts', type=Path, default=ROOT/'.local/assets/fonts')
    parser.add_argument('--output', type=Path, default=ROOT/'.local/assets')
    parser.add_argument('--prepared-music', type=Path, help='Reuse a verified private music directory instead of encoding again')
    args = parser.parse_args(); output = args.output.resolve(); fonts = args.fonts.resolve()
    if output == ROOT or output == args.original.resolve(): raise ValueError('Use a dedicated private output directory')
    archive = args.original/'th15.dat'; layout = music_layout(archive)
    font_manifest = json.loads((fonts/'manifest.json').read_text(encoding='utf-8'))
    required = {'cp932.bin','blend4444.bin'} | {f'font{i}.bin' for i in range(13)}
    files = {f['file']: f for f in font_manifest['files']}
    if required != set(files) or font_manifest['format'] != 'T15G-v3': raise ValueError('Expected 13 measured T15G-v3 fonts')
    for name, record in files.items():
        path = fonts/name
        if path.stat().st_size != record['bytes'] or sha(path) != record['sha256']: raise ValueError('Font hash mismatch: '+name)
    output.mkdir(parents=True, exist_ok=True)
    if archive.resolve() != (output/'th15.dat').resolve(): shutil.copy2(archive, output/'th15.dat')
    if fonts != output/'fonts': shutil.copytree(fonts, output/'fonts', dirs_exist_ok=True)
    if args.prepared_music:
        music = args.prepared_music.resolve(); manifest = json.loads((music/'manifest.json').read_text(encoding='utf-8'))
        if len(manifest['tracks']) != 18 or manifest['layoutSha256'] != hashlib.sha256(layout).hexdigest() or manifest['sourceBytes'] != (args.original/'thbgm.dat').stat().st_size: raise ValueError('Music source/layout mismatch')
        for track in manifest['tracks']:
            path = music/(Path(track['filename']).stem+'.ogg')
            if path.stat().st_size != track['bytes'] or sha(path) != track['sha256']: raise ValueError('Music hash mismatch')
        if music != output/'music': shutil.copytree(music, output/'music', dirs_exist_ok=True)
    else: convert_music(args.original/'thbgm.dat', layout, output/'music')
    records = {p.relative_to(output).as_posix(): {'bytes':p.stat().st_size,'sha256':sha(p)} for p in sorted(output.rglob('*')) if p.is_file() and p != output/'manifest.json'}
    (output/'manifest.json').write_text(json.dumps({'game':'TH15','language':'Japanese 1.00b','files':records},indent=2)+'\n',encoding='utf-8')
    print(f'Prepared {len(records)} private resources in {output}')

if __name__ == '__main__': main()
