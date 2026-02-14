#!/usr/bin/env python3
import glob
import re
import sys


def locale_keys(path: str):
    with open(path, encoding='utf-8') as f:
        text = f.read()
    return set(re.findall(r'L\["([^"]+)"\]\s*=', text))


def main() -> int:
    base_path = 'Locales/enUS.lua'
    base = locale_keys(base_path)
    ok = True
    for path in sorted(glob.glob('Locales/*.lua')):
        keys = locale_keys(path)
        missing = sorted(base - keys)
        extra = sorted(keys - base)
        if missing or extra:
            ok = False
            print(f'{path}: missing={len(missing)} extra={len(extra)}')
            if missing:
                print('  missing keys:', ', '.join(missing[:10]))
            if extra:
                print('  extra keys:', ', '.join(extra[:10]))
    if ok:
        print(f'Locale key parity OK across {len(glob.glob("Locales/*.lua"))} files')
        return 0
    return 1


if __name__ == '__main__':
    sys.exit(main())
