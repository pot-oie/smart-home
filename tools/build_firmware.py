"""Configure and build firmware only; never connects to or flashes a board."""
import argparse
import os
from pathlib import Path
import subprocess
from stm32_tools import find_tool

ROOT = Path(__file__).resolve().parents[1]
PROJECTS = {'sensors': ROOT/'硬件/温湿度与光照', 'rfid': ROOT/'硬件/RFID'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', choices=PROJECTS, required=True)
    parser.add_argument('--config', choices=['Debug', 'Release'], default='Debug')
    parser.add_argument('--relay-mode', choices=['off','high','low','probe'], default='off',
                        help='RFID project only; default off until hardware polarity is confirmed')
    args = parser.parse_args()
    if args.project != 'rfid' and args.relay_mode != 'off':
        parser.error('--relay-mode is only supported for the rfid project')
    # Prefer ST's versioned tools over system CMake/Ninja to reproduce the project.
    cmake = find_tool('STM32_CMAKE', 'cube-cmake', 'cmake/*/CMake.app/Contents/bin/cmake')
    ninja = find_tool('STM32_NINJA', 'cube-ninja', 'ninja/*/bin/ninja')
    gcc = find_tool('ARM_GCC', 'arm-none-eabi-gcc', 'gnu-tools-for-stm32/*/bin/arm-none-eabi-gcc')
    env = os.environ.copy()
    env['PATH'] = os.pathsep.join([str(gcc.parent), str(ninja.parent), env.get('PATH', '')])
    project = PROJECTS[args.project]
    configure=[str(cmake), '--preset', args.config, f'-DCMAKE_MAKE_PROGRAM={ninja}']
    if args.project == 'rfid':
        mode={'off':0,'high':1,'low':2,'probe':3}[args.relay_mode]
        configure.append(f'-DBOARD_RELAY_MODE={mode}')
    subprocess.run(configure, cwd=project, env=env, check=True)
    subprocess.run([str(cmake), '--build', '--preset', args.config], cwd=project, env=env, check=True)


if __name__ == '__main__':
    main()
