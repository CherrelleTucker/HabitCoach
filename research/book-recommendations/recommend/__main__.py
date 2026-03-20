"""Entry point for `uv run python -m recommend`."""

import sys

from .cli import main

if __name__ == "__main__":
    sys.exit(main())
