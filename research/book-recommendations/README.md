# Goodreads Tools

Utilities for processing Goodreads library exports.

## Installation

```bash
cd book-recommendations
uv sync

# Optional: Install Playwright for filtered review scraping
uv run playwright install chromium
```

## Utilities

### 1. Clean Export

Converts a raw Goodreads CSV export into a clean format with only essential columns.

```bash
uv run python -m goodreads clean <input.csv> <output.csv>
```

**Input**: Raw Goodreads export (all columns)
**Output**: Clean CSV with columns:
- `goodreads_id` - Book ID for URL construction
- `title` - Book title
- `author` - Primary author
- `my_rating` - Your rating (0-5)
- `my_review` - Your review text

Only books marked as "read" are included.

### 2. Add Genres

Scrapes genre information from Goodreads and adds it to a clean export.

```bash
uv run python -m goodreads genres <input.csv> <output.csv>
```

**Features**:
- Async HTTP requests with configurable concurrency
- Automatic retries with exponential backoff
- Progress bar with ETA
- Graceful failure handling (saves progress on interrupt)

**Options**:
- `--concurrency N` - Number of parallel requests (default: 5)
- `--retry N` - Max retry attempts (default: 3)

**Output**: Same CSV with added `genres` column (pipe-separated list).

## URL Format

Goodreads book pages: `https://www.goodreads.com/book/show/{goodreads_id}`

## Project Structure

```
book-recommendations/
├── data/
│   ├── goodreads_export_raw.csv   # Original Goodreads export
│   ├── read_books.csv             # Cleaned (read books only)
│   └── read_books_with_genres.csv # With scraped genres
├── output/                        # Generated visualizations
│   ├── genre_histogram.png
│   ├── fiction_breakdown.png
│   ├── rating_by_genre.png
│   └── stats.txt
├── goodreads/
│   ├── __init__.py
│   ├── clean.py      # Export conversion
│   ├── scrape.py     # Genre scraping (async)
│   ├── analyze.py    # Genre analysis and visualization
│   └── cli.py        # Command-line interface
└── README.md
```

### 3. Analyze Genres

Generates visualizations and statistics from genre data.

```bash
uv run python -m goodreads analyze <input.csv> <output_dir>
```

**Input**: CSV with genres column (from 'genres' command)
**Output**: Directory containing:
- `genre_histogram.png` - Bar chart of books per genre
- `fiction_breakdown.png` - Pie chart of fiction vs non-fiction
- `rating_by_genre.png` - Average rating per genre
- `stats.txt` - Summary statistics

**Statistics generated**:
- Total books and unique genres
- Fiction vs non-fiction counts and percentages
- Average rating by genre (sorted)
- Top genres by book count
- Top genres by average rating (min 3 books)

## Example Workflow

```bash
# Clean raw export
uv run python -m goodreads clean data/goodreads_export_raw.csv data/read_books.csv

# Add genres
uv run python -m goodreads genres data/read_books.csv data/read_books_with_genres.csv

# Analyze genres
uv run python -m goodreads analyze data/read_books_with_genres.csv output/
```

---

## Recommendation Pipeline

For generating personalized book recommendations, see the **[recommend module](recommend/README.md)**.

```bash
# Quick start
uv run python -m recommend status                        # Check pipeline state
uv run python -m recommend check-read "<title>" "<author>"  # Already read?
uv run python -m recommend check-series <id>             # Resolve to Book 1
uv run python -m recommend add <id> "<title>" "<author>" # Add candidate
uv run python -m recommend scrape-candidates             # Fetch metadata/reviews
uv run python -m recommend list-ready                    # Books needing analysis
uv run python -m recommend generate-report               # Create recommendations.md
```

The recommendation system is LLM-orchestrated: Claude generates search queries, reviews candidates, and makes recommendations while Python handles scraping and data management.
