"""Preserve original DuoDash payload, replacing only its fullscreen helper.

Usage: python3 scripts/package-duodash-fullscreen.py BASE.deb ADAPTER.deb OUT.deb
This is a packaging/static verification gate, not a CarPlay runtime test.
"""
import hashlib
import io
import pathlib
import plistlib
import subprocess
import sys
import tarfile
import tempfile

base, adapter, output = map(pathlib.Path, sys.argv[1:])
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
addition = contents(adapter)
metadata = contents(base, True)
removed = {
    'var/jb/usr/lib/TweakInject/DuoDashUnifiedFullscreen.dylib',
    'var/jb/usr/lib/TweakInject/DuoDashUnifiedFullscreen.plist',
}
assert removed <= original.keys()
prefix = 'var/jb/Library/MobileSubstrate/DynamicLibraries/DuoDashFullscreenAdapter'
assert set(addition) == {prefix + '.dylib', prefix + '.plist'}, addition.keys()
assert plistlib.loads(addition[prefix + '.plist'][0])['Filter']['Bundles'] == [
    'com.apple.CarPlayTemplateUIHost']
adapter_control = contents(adapter, True)['control'][0].decode()
assert 'Package: com.chuong.duodash-fullscreen\n' in adapter_control
assert 'Architecture: iphoneos-arm64\n' in adapter_control
payload = {name: value for name, value in original.items() if name not in removed}
assert not (payload.keys() & addition.keys())
payload.update(addition)

# Register the shipped native controller explicitly. The source package's
# inline entry never names DuoDashPrefs.bundle. Keep the full original settings
# list for both the native controller and any original inline-plist hooks.
loader_path = 'var/jb/Library/PreferenceLoader/Preferences/DuoDashPrefs.plist'
root_path = 'var/jb/Library/PreferenceBundles/DuoDashPrefs.bundle/Root.plist'
loader = plistlib.loads(original[loader_path][0])
original_items = loader['items']
loader['entry'].update({
    'bundle': 'DuoDashPrefs',
    'bundlePath': '/var/jb/Library/PreferenceBundles/DuoDashPrefs.bundle',
    'isController': True,
    'icon': '/var/jb/Library/PreferenceBundles/DuoDashPrefs.bundle/icon@2x.png',
})
root_plist = plistlib.loads(original[root_path][0])
root_plist['title'] = loader['title']
root_plist['items'] = original_items
for name, document in ((loader_path, loader), (root_path, root_plist)):
    payload[name] = (plistlib.dumps(document, fmt=plistlib.FMT_XML, sort_keys=False),
                     original[name][1])
settings_modified = {loader_path, root_path}
assert root_plist['items'] == plistlib.loads(original[loader_path][0])['items']
assert plistlib.loads(original[
    'var/jb/Library/PreferenceBundles/DuoDashPrefs.bundle/Info.plist'][0]
)['NSPrincipalClass'] == 'DuoDashRootListController'

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
    'Version': '1.1.3+adapter1~test2',
    'Architecture': 'iphoneos-arm64',
    'Maintainer': 'chuongnguyen89dn-ui',
    'Author': 'SenseTechLab (DuoDash); chuongnguyen89dn-ui (adapter)',
    'Section': 'Tweaks',
    'Depends': fields['Depends'],
    'Conflicts': ', '.join(dict.fromkeys(conflicts)),
    'Replaces': ', '.join(dict.fromkeys(conflicts)),
    'Provides': fields.get('Provides', '') + ', com.sensetechlab.duodash (= 1.1.3)',
    'Description': ('Original DuoDash 1.1.3 UI, app picker and split engine with '
                    'fullscreen adapter. Test build; physical CarPlay behavior '
                    'has not been verified. Replaces older fullscreen helper; no Airaw.'),
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
assert all(result[name] == value for name, value in original.items() if name not in removed | settings_modified)
assert plistlib.loads(result[root_path][0])['items'] == original_items
assert plistlib.loads(result[loader_path][0])['entry']['bundle'] == 'DuoDashPrefs'
assert not any('Airaw' in name or 'AiraW' in name or 'CarPlaySplit' in name for name in result)
assert not (removed & result.keys())
assert contents(output, True)['postinst'] == metadata['postinst']
assert contents(output, True)['prerm'] == metadata['prerm']
print(f'PASS: {len(original) - len(removed) - len(settings_modified)} original DuoDash files preserved byte-for-byte; '
      'fullscreen helper replaced; Settings registration uses native bundle with all original rows.')
print(f'SHA256 {hashlib.sha256(output.read_bytes()).hexdigest()}  {output}')
