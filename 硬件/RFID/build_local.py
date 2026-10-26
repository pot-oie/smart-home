from pathlib import Path
import subprocess
import sys
root = Path(__file__).resolve().parents[2]
subprocess.run([sys.executable, str(root/'tools/build_firmware.py'), '--project', 'rfid'], check=True)
