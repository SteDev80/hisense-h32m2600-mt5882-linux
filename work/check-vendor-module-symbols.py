"""Read-only compatibility screening; symbol presence is not an ABI guarantee."""
import json
import pathlib
import subprocess
import sys

exports = set()
for line in pathlib.Path(sys.argv[1]).read_text().splitlines():
    fields = line.split()
    if len(fields) >= 3 and fields[2] == 'vmlinux':
        exports.add(fields[1])
report = []
for module in sorted(pathlib.Path(sys.argv[2]).rglob('*.ko')):
    output = subprocess.check_output(['readelf', '-Ws', str(module)], text=True)
    needed = set()
    for line in output.splitlines():
        fields = line.split()
        if len(fields) >= 8 and fields[6] == 'UND' and fields[4] != 'WEAK':
            needed.add(fields[7])
    report.append(dict(module=str(module), required_symbols=len(needed),
                       missing_exports=sorted(needed - exports)))
print(json.dumps(report, indent=2))
