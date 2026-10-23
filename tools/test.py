"""Compatibility entrypoint for the separate process-bounded test suites."""
import sys
from test_suites import main
if __name__ == '__main__':
    sys.exit(main())
