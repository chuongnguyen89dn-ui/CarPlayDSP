"""Verify the package payload and minimum Mach-O structure; no runtime claim."""
import io, pathlib, plistlib, struct, subprocess, sys, tarfile
package = pathlib.Path(sys.argv[1])
data = subprocess.check_output(['dpkg-deb', '--fsys-tarfile', str(package)])
with tarfile.open(fileobj=io.BytesIO(data), mode='r:') as archive:
    files = {m.name.removeprefix('./'): archive.extractfile(m).read() for m in archive.getmembers() if m.isfile()}
def inspect_macho(blob, expected_type):
    magic = blob[:4]
    if magic in (b'\xca\xfe\xba\xbe', b'\xca\xfe\xba\xbf'):
        count = struct.unpack_from('>I', blob, 4)[0]
        stride = 32 if magic[-1] == 0xbf else 20
        assert 0 < count < 10
        for index in range(count):
            offset = 8 + index * stride
            if stride == 32:
                start, length = struct.unpack_from('>QQ', blob, offset + 8)
            else:
                start, length = struct.unpack_from('>II', blob, offset + 8)
            assert start + length <= len(blob)
            inspect_macho(blob[start:start + length], expected_type)
        return
    assert magic == b'\xcf\xfa\xed\xfe'
    _, cpu, _, filetype, count, commands_size, _, _ = struct.unpack_from('<8I', blob)
    assert cpu == 0x100000c and filetype == expected_type
    assert 32 + commands_size <= len(blob)
    cursor, signed, ios, dependencies = 32, False, False, []
    for _ in range(count):
        command, length = struct.unpack_from('<II', blob, cursor)
        assert length >= 8 and cursor + length <= 32 + commands_size
        if command == 0x19:
            sections = struct.unpack_from('<I', blob, cursor + 64)[0]
            for section in range(sections):
                position = cursor + 72 + section * 80
                assert position + 80 <= cursor + length
                name = blob[position:position + 16].split(b'\0', 1)[0]
                size = struct.unpack_from('<Q', blob, position + 40)[0]
                offset = struct.unpack_from('<I', blob, position + 48)[0]
                flags = struct.unpack_from('<I', blob, position + 64)[0]
                if size and (flags & 0xff) not in (1, 0xc, 0x12):
                    assert offset >= 32 + commands_size, f'Load commands overwrite section {name!r}'
                    assert offset + size <= len(blob)
        if command == 0x1d:
            start, size = struct.unpack_from('<II', blob, cursor + 8)
            assert size > 0 and start + size <= len(blob)
            assert blob[start:start + 4] == b'\xfa\xde\x0c\xc0'
            signed = True
        elif command == 0x32:
            platform, minimum = struct.unpack_from('<II', blob, cursor + 8)
            ios = platform == 2 and minimum <= 0x100000
        elif command in (0xc, 0x80000018, 0x8000001f):
            name_offset = struct.unpack_from('<I', blob, cursor + 8)[0]
            name = blob[cursor + name_offset:cursor + length].split(b'\0', 1)[0].decode()
            assert name.startswith(('/usr/lib/', '/System/Library/')), name
            dependencies.append(name)
        cursor += length
    assert cursor == 32 + commands_size
    assert signed and ios and dependencies, 'Signature, iOS target or linked libraries missing'

base = 'var/jb/'
app = base + 'Applications/CarPlaySplit.app/'
dylib = base + 'Library/MobileSubstrate/DynamicLibraries/CarPlaySplit.dylib'
assert not any('DuoDash' in name or 'Airaw' in name for name in files), 'Reference payload leaked into package'
prefs = base + 'Library/PreferenceBundles/CarPlaySplitPrefs.bundle/'
for name in [app + 'CarPlaySplit', dylib, prefs + 'CarPlaySplitPrefs']:
    assert name in files, f'Missing binary: {name}'
    assert files[name][:4] in (b'\xcf\xfa\xed\xfe', b'\xca\xfe\xba\xbe', b'\xca\xfe\xba\xbf'), f'Not Mach-O: {name}'
    assert len(files[name]) > 4096, f'Truncated binary: {name}'
    inspect_macho(files[name], 2 if name.endswith('/CarPlaySplit') else 8 if name.endswith('/CarPlaySplitPrefs') else 6)
info = plistlib.loads(files[app + 'Info.plist'])
assert info['CFBundleIdentifier'] == 'com.chuong.carplaysplit'
assert info['CFBundleExecutable'] == 'CarPlaySplit'
control = subprocess.check_output(['dpkg-deb', '-f', str(package)]).decode()
assert 'Package: com.chuong.carplaysplit\n' in control
assert 'Architecture: iphoneos-arm64\n' in control
assert 'Alpha build' in control
print(f'Package inspected: {len(files)} payload files, app and tweak present, no reference binaries.')

filter_plist = plistlib.loads(files[base + 'Library/MobileSubstrate/DynamicLibraries/CarPlaySplit.plist'])
assert set(filter_plist['Filter']['Executables']) == {'SpringBoard', 'CarPlay'}
print('Verified signed arm64 Mach-O slices, iOS deployment target and system-only dependencies.')

prefs_info=plistlib.loads(files[prefs+'Info.plist'])
assert prefs_info['NSPrincipalClass']=='CPSPreferencesController'
loader=plistlib.loads(files[base+'Library/PreferenceLoader/Preferences/CarPlaySplitPrefs.plist'])
assert loader['entry']['bundle']=='CarPlaySplitPrefs'
assert 'preferenceloader' in control
print('Verified Settings bundle, loader entry, dependency and signed bundle slices.')
