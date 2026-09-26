import sys

from rules_sync import sync

COMMANDS = {"sync": sync.main}

if len(sys.argv) < 2 or sys.argv[1] not in COMMANDS:
    sys.exit(f"usage: python -m rules_sync {{{'|'.join(COMMANDS)}}} [options]")
COMMANDS[sys.argv[1]](sys.argv[2:])
