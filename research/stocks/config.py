"""Configuration for stock analysis framework."""

import os

# Default date range
DEFAULT_START_DATE = "2010-01-01"
DEFAULT_END_DATE = None  # None means today

# Base date for inflation adjustment (prices expressed in this date's dollars)
DEFAULT_BASE_DATE = "2020-01-01"

# Cache settings
CACHE_DIR = os.path.join(os.path.dirname(__file__), ".cache")
CACHE_EXPIRY_DAYS = 1
