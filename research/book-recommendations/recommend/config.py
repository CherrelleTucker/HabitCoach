"""Configuration settings for the recommendation system."""

from pathlib import Path

# Paths
BASE_DIR = Path(__file__).parent.parent
DATA_DIR = BASE_DIR / "data"
LIBRARY_DIR = BASE_DIR / "library"
OUTPUT_DIR = BASE_DIR / "output"

# Input files
READ_BOOKS_CSV = DATA_DIR / "read_books_with_genres.csv"
USER_PROFILE_MD = BASE_DIR / "user_profile.md"

# Search settings
SIMILAR_BOOK_SEARCHES_PER_FAVORITE = 2
MAX_STYLE_SEARCHES = 10
SEARCH_MAX_RESULTS = 10

# Candidate settings
MIN_FREQUENCY_SCORE = 1
TOP_CANDIDATES_FOR_REVIEW = 50

# Scraping settings
REVIEWS_PER_STAR_RATING = 3
SCRAPE_DELAY_SECONDS = 1.5
MAX_CONCURRENT_REQUESTS = 5
MAX_RETRIES = 3

# Fuzzy matching threshold for deduplication (0-100)
FUZZY_MATCH_THRESHOLD = 85

# Authors to avoid (from user profile)
AVOID_AUTHORS = [
    "M.R. Carey",
    "Martha Wells",
    "Cassandra Clare",
    "Becky Chambers",
    "Frank Herbert",
    "Patrick Rothfuss",
    "James Islington",
    "Liu Cixin",
]

# Favorite authors (from user profile)
FAVORITE_AUTHORS = [
    "Ted Chiang",
    "Ken Liu",
    "Ursula K. Le Guin",
    "Jane Austen",
    "Daphne du Maurier",
    "Kazuo Ishiguro",
    "Brandon Sanderson",
    "Brent Weeks",
    "Joe Abercrombie",
    "China Miéville",
    "Susanna Clarke",
    "Madeline Miller",
    "Adrian Tchaikovsky",
    "Arkady Strugatsky",
    "Boris Strugatsky",
    "James S.A. Corey",
    "Margaret Atwood",
]

# HTTP settings
USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
GOODREADS_BASE_URL = "https://www.goodreads.com"
