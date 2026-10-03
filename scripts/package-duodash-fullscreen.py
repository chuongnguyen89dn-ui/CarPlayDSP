"""Restore the complete source DuoDash payload after an adapter regression.

Usage: python3 scripts/package-duodash-fullscreen.py BASE.deb OUT.deb
This is a packaging/static verification gate, not a CarPlay runtime test.
"""
import hashlib
import io
import pathlib
import subprocess
import sys
import tarfile
import tempfile

base, output = map(pathlib.Path, sys.argv[1:])
assert hashlib.sha256(base.read_bytes()).hexdigest() == (
    'ea0d3bb8c8b9da2b45c3f158f390a7966419e84899f820d06f45cd51401fa465'
), 'Unexpected DuoDash base package'


def contents(package, control=False):
    flag = '--ctrl-tarfile' if control else '--fsys-tarfile'
    raw = subprocess.check_output(['dpkg-deb', flag, str(package)])
    with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
        return {m.name.removeprefix('./'): (archive.extractfile(m).read(), m.mode)
                for m in archive if m.isfile()}


original = contents(base)
metadata = contents(base, True)
# Recovery release: no adapter, no frame hooks, no divider touch hooks.
# Restore every source file, including its existing fullscreen helper.
payload = dict(original)

fields = {}
for line in metadata['control'][0].decode().splitlines():
    if line and not line[0].isspace() and ':' in line:
        key, value = line.split(':', 1)
        fields[key] = value.strip()
conflicts = [x.strip() for x in fields['Conflicts'].split(',')]
conflicts += ['com.sensetechlab.duodash', 'com.axs.airaw',
              'com.chuong.duodash-airaw', 'com.chuong.duodash.airawengine',
              'com.chuong.carplaysplit', 'com.chuong.duodash-fullscreen']
control = {
    'Package': 'com.chuong.duodash-fullscreen-complete',
    'Name': 'DuoDash Fullscreen (Original UI)',
    'Version': '1.1.3+adapter1~test4',
    'Architecture': 'iphoneos-arm64',
    'Maintainer': 'chuongnguyen89dn-ui',
    'Author': 'SenseTechLab (DuoDash); chuongnguyen89dn-ui (adapter)',
    'Section': 'Tweaks',
    'Depends': fields['Depends'],
    'Conflicts': ', '.join(dict.fromkeys(conflicts)),
    'Replaces': ', '.join(dict.fromkeys(conflicts)),
    'Provides': fields.get('Provides', '') + ', com.sensetechlab.duodash (= 1.1.3)',
    'Description': ('Recovery build restoring every original DuoDash source file. '
                    'Experimental fullscreen/bar adapter removed after divider drag regression. '
                    'Original UI, app picker, Settings and split payload preserved; '
                    'device behavior requires verification.'),
}

with tempfile.TemporaryDirectory(prefix='duodash-package-') as temp:
    root = pathlib.Path(temp)
    for name, (data, mode) in payload.items():
        path = root / name
        assert '..' not in pathlib.PurePosixPath(name).parts and not name.startswith('/')
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        path.chmod(mode)
    debian = root / 'DEBIAN'
    debian.mkdir()
    for name in ('postinst', 'prerm'):
        data, mode = metadata[name]
        (debian / name).write_bytes(data)
        (debian / name).chmod(mode)
    (debian / 'control').write_text(''.join(f'{k}: {v}\n' for k, v in control.items()))
    (debian / 'md5sums').write_text(''.join(
        f'{hashlib.md5(data).hexdigest()}  {name}\n'
        for name, (data, _) in sorted(payload.items())))
    output.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(['dpkg-deb', '--build', '--root-owner-group', str(root), str(output)], check=True)

result = contents(output)
assert result == payload, 'Payload bytes or permissions changed during packaging'
assert result == original, 'Recovery must preserve the complete source payload'
assert not any('Airaw' in name or 'AiraW' in name or 'CarPlaySplit' in name for name in result)
assert not any('DuoDashFullscreenAdapter' in name for name in result)
assert contents(output, True)['postinst'] == metadata['postinst']
assert contents(output, True)['prerm'] == metadata['prerm']
print(f'PASS: {len(original)} original DuoDash files preserved byte-for-byte; '
      'experimental adapter absent; complete source payload restored.')
print(f'SHA256 {hashlib.sha256(output.read_bytes()).hexdigest()}  {output}')
