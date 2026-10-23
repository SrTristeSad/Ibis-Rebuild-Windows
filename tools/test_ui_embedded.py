"""Compatibility entrypoint: graphical tests now run in the official runtime.
The original crashing host is preserved locally under tools/archive/.
No Lua/L?VE/SDL state is created or closed by this Python script.
"""
import sys
from test_ui import main
if __name__ == '__main__':
    print('The embedded UI host has been retired; executing official-runtime UI tests.', file=sys.stderr)
    sys.exit(main())
