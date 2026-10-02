"""Label the exact source DEB in the APT index; never modify/repack the DEB."""
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
blocks = path.read_text().strip().split("\n\n")
matches = 0
for index, block in enumerate(blocks):
    lines = block.splitlines()
    fields = dict(line.split(": ", 1) for line in lines
                  if ": " in line and not line.startswith(" "))
    if fields.get("Package") != "com.sensetechlab.duodash":
        continue
    assert fields["Version"] == "1.1.3+fullscreen1", fields
    assert fields["SHA256"] == "ea0d3bb8c8b9da2b45c3f158f390a7966419e84899f820d06f45cd51401fa465"
    assert fields["Filename"] == "debs/DuoDash-Source_1.1.3+fullscreen1_iphoneos-arm64.deb"
    lines = [line for line in lines if not line.startswith("Name:")]
    lines.append("Name: DuoDash (Source DEB)")
    blocks[index] = "\n".join(lines)
    matches += 1
assert matches == 1, f"Expected exactly one untouched DuoDash baseline, got {matches}"
path.write_text("\n\n".join(blocks) + "\n\n")
print("Verified exact baseline hash; Sileo label added without changing DEB")
