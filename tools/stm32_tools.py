"""Locate installed ST tools without depending on another developer's paths."""
import os
from pathlib import Path
import re
import shutil

BUNDLES = Path(os.environ.get('CUBE_BUNDLE_PATH', Path.home() / 'Library/Application Support/stm32cube/bundles'))


def find_tool(variable, executable, pattern):
    override = os.environ.get(variable)
    if override:
        path = Path(override).expanduser()
        if not path.is_file():
            raise RuntimeError(f'{variable} 指向不存在的文件：{path}')
        return path
    found = shutil.which(executable)
    if found:
        return Path(found)
    def version_key(path):
        return tuple(int(x) for x in re.findall(r'\d+', str(path.relative_to(BUNDLES))))
    matches = sorted(BUNDLES.glob(pattern), key=version_key, reverse=True)
    if matches:
        return matches[0]
    raise RuntimeError(f'找不到 {executable}，请安装 ST 工具包或设置 {variable}')
