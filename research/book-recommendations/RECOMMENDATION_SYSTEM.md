# Book Recommendation System

A multi-stage pipeline for generating personalized book recommendations based on the user profile.

---

## Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           CANDIDATE GENERATION                               │
├─────────────────────────────────────────────────────────────────────────────┤
│  Stage 1A: Similar Books Search                                             │
│  - Web search "books similar to [S-tier book]" for each favorite            │
│  - Web search "books like [S-tier book]" (alternate phrasing)               │
│  - Extract book titles and authors from results                             │
│                                                                             │
│  Stage 1B: Author Discovery                                                 │
│  - For each favorite author, find their other works                         │
│  - Web search "best [author name] books" or scrape Goodreads author page    │
│                                                                             │
│  Stage 1C: Style-Based Search                                               │
│  - Search for books matching key style preferences from profile             │
│  - "books with unreliable narrator", "fantasy with hard magic systems"      │
│  - "science fiction immersive worldbuilding"                                │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           CANDIDATE COMPILATION                              │
├─────────────────────────────────────────────────────────────────────────────┤
│  - Deduplicate by title/author                                              │
│  - Resolve series → always use Book 1                                       │
│  - Look up Goodreads ID for each candidate                                  │
│  - Score by frequency (books appearing from multiple sources rank higher)   │
│  - Filter out already-read books (check against read_books_with_genres.csv) │
│  - Filter out books by authors on the "avoid" list                          │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           REVIEW ANALYSIS                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│  For each candidate (top N by frequency score):                             │
│  - Fetch Goodreads page                                                     │
│  - Scrape 2-3 reviews from each star category (5★, 3★, 1★)                  │
│  - Extract common praise/criticism themes                                   │
│  - Check against user's "hate" patterns                                     │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           LLM FILTERING                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│  For each candidate with reviews:                                           │
│  - Provide user profile (loves/hates) + scraped reviews                     │
│  - Ask: "Would this reader enjoy this book? Why or why not?"                │
│  - Generate confidence score and reasoning                                  │
│  - Flag potential dealbreakers from hate list                               │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           FINAL OUTPUT                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│  - Ranked list of recommendations with reasoning                            │
│  - Grouped by confidence tier (High / Medium / Worth a Try)                 │
│  - Include source (which favorite led to this recommendation)               │
│  - Note any caveats based on hate-list matches                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Execution Model

This system is **LLM-orchestrated**: Claude generates inputs and makes decisions, Python tools handle mechanical execution. This hybrid approach leverages LLM strengths (nuance, judgment, natural language) while offloading repetitive work to code.

### What the LLM Does

| Stage | LLM Responsibility |
|-------|-------------------|
| **Search Generation** | Generate detailed, varied search queries based on user profile. Knows to search for "books with creeping revelation like Piranesi" not just "books similar to Piranesi" |
| **Candidate Triage** | Review raw search results, identify duplicates with fuzzy matching, flag series that need resolution |
| **Series Resolution** | Determine if a book is part of a series, identify Book 1, handle edge cases (shared universes, reading order debates) |
| **Review Analysis** | Read scraped reviews, extract themes, match against hate patterns with nuance ("this reviewer complains about slow pacing, but the user has high tolerance for that") |
| **Final Recommendations** | Synthesize all data into reasoned recommendations with confidence tiers |

### What Python Tools Do

| Tool | Responsibility |
|------|---------------|
| `search` | Execute web searches, return raw results |
| `scrape` | Fetch Goodreads pages, extract reviews/metadata |
| `library` | Store/retrieve cached data, track what's been processed |
| `lookup` | Resolve Goodreads IDs, fetch series info |
| `filter` | Apply mechanical filters (already-read, blacklisted authors) |
| `report` | Generate final markdown output from structured data |

### Execution Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ PHASE 1: SEARCH GENERATION (LLM)                                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  LLM reads: user_profile.md                                                 │
│                                                                             │
│  LLM generates:                                                             │
│    similar_searches.json    - ["books similar to Piranesi", ...]            │
│    author_searches.json     - ["Ted Chiang bibliography", ...]              │
│    style_searches.json      - ["fantasy immersive worldbuilding", ...]      │
│                                                                             │
│  These are saved to library/searches/pending/                               │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ PHASE 2: SEARCH EXECUTION (Python)                                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  uv run python -m recommend execute-searches                                │
│                                                                             │
│  For each pending search:                                                   │
│    - Execute web search                                                     │
│    - Parse results into (title, author, snippet) tuples                     │
│    - Save to library/searches/{type}/{query_slug}.json                      │
│    - Mark search as completed                                               │
│                                                                             │
│  Output: library/searches/results_pending_review.json                       │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ PHASE 3: CANDIDATE CONSOLIDATION (LLM)                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  LLM reads: library/searches/results_pending_review.json                    │
│             data/read_books_with_genres.csv                                 │
│                                                                             │
│  LLM does:                                                                  │
│    - Deduplicate with fuzzy matching ("The Left Hand of Darkness" =         │
│      "Left Hand of Darkness, The")                                          │
│    - Identify series entries, note which need Book 1 resolution             │
│    - Filter out already-read books                                          │
│    - Filter out blacklisted authors                                         │
│    - Score by frequency and source quality                                  │
│    - Select top N for review scraping                                       │
│                                                                             │
│  LLM outputs: library/candidates_for_scraping.json                          │
│    [                                                                        │
│      {                                                                      │
│        "title": "Annihilation",                                             │
│        "author": "Jeff VanderMeer",                                         │
│        "needs_series_resolution": false,                                    │
│        "sources": ["similar:Roadside Picnic", "similar:Piranesi"],          │
│        "frequency_score": 2                                                 │
│      },                                                                     │
│      ...                                                                    │
│    ]                                                                        │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ PHASE 4: METADATA & REVIEW SCRAPING (Python)                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  uv run python -m recommend scrape-candidates                               │
│                                                                             │
│  For each candidate in candidates_for_scraping.json:                        │
│    - Look up Goodreads ID (search or direct URL)                            │
│    - Fetch book page, extract metadata (genres, ratings, series info)       │
│    - If series book > 1: fetch series page, get Book 1 info                 │
│    - Scrape reviews (N per star rating)                                     │
│    - Save to library/books/{goodreads_id}.json                              │
│    - Update library/index.json                                              │
│                                                                             │
│  Output: Books ready for analysis in library/books/                         │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ PHASE 5: REVIEW ANALYSIS & RECOMMENDATIONS (LLM)                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  LLM reads: library/books/*.json (candidates with reviews)                  │
│             user_profile.md                                                 │
│                                                                             │
│  For each book, LLM:                                                        │
│    - Reads 5-star, 3-star, 1-star reviews                                   │
│    - Extracts themes (praised for, criticized for, divisive)                │
│    - Matches against hate patterns with nuance                              │
│    - Considers genre affinity from profile                                  │
│    - Makes recommendation (high/medium/try/skip) with reasoning             │
│                                                                             │
│  LLM outputs: Updates each library/books/{id}.json with analysis            │
│               Generates output/recommendations.md                           │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Example LLM-Generated Search Terms

When generating searches, the LLM should be creative and varied:

**For S-tier book "Piranesi" by Susanna Clarke:**
```json
{
  "seed": "Piranesi",
  "author": "Susanna Clarke",
  "searches": [
    "books similar to Piranesi",
    "books like Piranesi Susanna Clarke",
    "novels with mysterious architecture like Piranesi",
    "fantasy books with unreliable narrator gentle tone",
    "books with creeping revelation mystery",
    "literary fantasy puzzlebox novels",
    "Piranesi readalikes reddit"
  ]
}
```

**For favorite author Ted Chiang:**
```json
{
  "author": "Ted Chiang",
  "searches": [
    "Ted Chiang all books",
    "Ted Chiang short story collections",
    "Ted Chiang bibliography",
    "authors similar to Ted Chiang",
    "short story writers like Ted Chiang"
  ]
}
```

**For style preference "immersive worldbuilding":**
```json
{
  "style": "immersive worldbuilding",
  "searches": [
    "fantasy books immersive worldbuilding",
    "science fiction thrown into world no explanation",
    "books that don't hold your hand worldbuilding",
    "novels with organic world revelation",
    "best worldbuilding fantasy novels reddit"
  ]
}
```

### CLI Commands

The Python tools expose simple commands that the LLM calls via Bash:

```bash
# Execute all pending searches (reads from library/searches/pending/)
uv run python -m recommend execute-searches

# Scrape candidates (reads from library/candidates_for_scraping.json)
uv run python -m recommend scrape-candidates

# Check what needs processing
uv run python -m recommend status
# Output:
#   Pending searches: 45
#   Candidates awaiting scrape: 23
#   Books with reviews, no analysis: 12
#   Books fully processed: 89

# Scrape additional reviews for a specific book
uv run python -m recommend scrape-more-reviews --id 12345 --stars 1 --count 5

# Generate recommendations report from analyzed books
uv run python -m recommend generate-report
```

### Typical Session Flow

```
User: "Generate book recommendations"

LLM: I'll start by generating search terms based on your profile.
     [Reads user_profile.md]
     [Generates search JSONs, saves to library/searches/pending/]
     [Calls: uv run python -m recommend execute-searches]

LLM: Searches complete. Let me consolidate the candidates.
     [Reads raw search results]
     [Deduplicates, filters, scores]
     [Outputs candidates_for_scraping.json]
     [Calls: uv run python -m recommend scrape-candidates]

LLM: Reviews scraped. Now I'll analyze each candidate.
     [Reads each book's reviews from library/books/]
     [Analyzes against profile, updates book records]
     [Generates output/recommendations.md]

LLM: Done! Here are your recommendations:
     [Presents high-confidence picks with reasoning]
```

---

## Stage 1: Candidate Generation

### 1A. Similar Books Search

**Input**: S-tier books from user profile

```
S-Tier Fiction:
- Roadside Picnic (Arkady Strugatsky)
- Stories of Your Life and Others (Ted Chiang)
- The Paper Menagerie and Other Stories (Ken Liu)
- Rebecca (Daphne du Maurier)
- The Remains of the Day (Kazuo Ishiguro)
- Leviathan Wakes (James S.A. Corey)
- A Wizard of Earthsea (Ursula K. Le Guin)
- The Handmaid's Tale (Margaret Atwood)
- Circe (Madeline Miller)
- Children of Time (Adrian Tchaikovsky)
- Piranesi (Susanna Clarke)
... (full list in user_profile.md)
```

**Search Queries** (for each S-tier book):
```
"books similar to {title}"
"books like {title} by {author}"
"if you liked {title} read"
"{title} readalikes"
```

**Expected Output**: List of (title, author) tuples with source attribution

**Implementation Notes**:
- Use WebSearch tool for each query
- Parse search results for book titles (look for patterns like "Title by Author")
- Store which S-tier book generated each candidate (for provenance)
- Run 2-3 search variations per S-tier book to maximize coverage

### 1B. Author Discovery

**Input**: Favorite authors from user profile

```
Favorites:
- Ted Chiang
- Ken Liu
- Ursula K. Le Guin
- Jane Austen
- Daphne du Maurier
- Kazuo Ishiguro
- Brandon Sanderson
- Brent Weeks
- Joe Abercrombie
- China Miéville
- Susanna Clarke
- Madeline Miller
... (full list in user_profile.md)
```

**Search Queries**:
```
"{author name} books list"
"{author name} bibliography"
"best {author name} books ranked"
```

**Alternative**: Scrape Goodreads author page
```
https://www.goodreads.com/author/show/{author_id}
```

**Implementation Notes**:
- For prolific authors, prioritize their highest-rated works
- Cross-reference against already-read list immediately
- Note series relationships (if user read book 1, recommend book 2)

### 1C. Style-Based Search

**Input**: Key style preferences extracted from user profile

```
Style Preferences (search-friendly phrasings):
- "science fiction immersive worldbuilding"
- "fantasy books that don't hold your hand"
- "books with creeping revelation"
- "science fiction ambiguous ending"
- "fantasy morally grey characters"
- "literary fiction unreliable narrator"
- "short story collections science fiction"
- "fantasy hard magic system"
- "books like Perdido Street Station worldbuilding"
- "science fiction character-driven"
```

**Search Queries**:
```
"best {style preference} books"
"{style preference} book recommendations"
"{style preference} novels reddit"
```

---

## Stage 2: Candidate Compilation

### 2A. Deduplication

```python
# Pseudocode for deduplication
candidates = {}  # key: normalized(title, author), value: CandidateInfo

for result in all_search_results:
    key = normalize(result.title, result.author)
    if key in candidates:
        candidates[key].sources.append(result.source)
        candidates[key].frequency += 1
    else:
        candidates[key] = CandidateInfo(
            title=result.title,
            author=result.author,
            sources=[result.source],
            frequency=1
        )
```

**Normalization Rules**:
- Lowercase title and author
- Remove subtitles (everything after ":")
- Remove series indicators like "(Book 1)"
- Handle "The" prefix variations
- Fuzzy match on author names (handle "J.R.R. Tolkien" vs "JRR Tolkien")

### 2B. Series Resolution

Books that are part of a series should always resolve to Book 1. This prevents recommending sequels the user can't start with.

**Detection Methods**:
1. Parse title for series indicators: "(Book 2)", "#3", "Vol. 4", etc.
2. Check Goodreads series page for the book
3. Web search "{title} series order"

**Resolution Process**:
```python
def resolve_to_book_one(candidate):
    """
    If candidate is book 2+ in a series, replace with book 1.
    Returns the resolved candidate with series metadata.
    """
    # Check if title contains series indicator
    series_match = re.search(r'\(.*?#?(\d+)\)|\bBook\s+(\d+)\b', candidate.title)

    if series_match:
        book_num = int(series_match.group(1) or series_match.group(2))
        if book_num > 1:
            # Look up book 1 in this series
            series_info = lookup_series(candidate.goodreads_id)
            book_one = series_info.books[0]

            return Candidate(
                title=book_one.title,
                author=candidate.author,
                goodreads_id=book_one.goodreads_id,
                series_name=series_info.name,
                original_recommendation=candidate.title,  # Track what was actually recommended
                sources=candidate.sources
            )

    return candidate
```

**Goodreads Series Lookup**:
```
URL: https://www.goodreads.com/book/show/{goodreads_id}
Extract: Series link from book page → fetch series page → get book 1
```

**Edge Cases**:
- Standalone books in a shared universe (e.g., Discworld) → treat as standalone
- Prequels numbered as "Book 0" → still recommend as entry point
- Books that work standalone despite being "Book 2" → note in metadata but still resolve to Book 1

### 2C. Goodreads ID Lookup

For each unique candidate:
```
Search: "{title} {author} site:goodreads.com"
Extract: goodreads_id from URL pattern /book/show/{id}
```

**Alternative**: Use Goodreads search directly
```
https://www.goodreads.com/search?q={title}+{author}
```

### 2D. Frequency Scoring

```python
# Score based on how many sources recommended this book
base_score = candidate.frequency

# Bonus for appearing from multiple S-tier books
unique_stier_sources = count_unique_stier_sources(candidate.sources)
if unique_stier_sources >= 3:
    base_score *= 1.5
elif unique_stier_sources >= 2:
    base_score *= 1.2

# Bonus for favorite author
if candidate.author in favorite_authors:
    base_score *= 1.3

# Penalty for author with mixed history
if candidate.author in mixed_authors:
    base_score *= 0.9

candidate.score = base_score
```

### 2E. Already-Read Filter

```python
# Load already-read books
read_books = load_csv("data/read_books_with_genres.csv")
read_set = {normalize(row.title, row.author) for row in read_books}

# Filter candidates
candidates = [c for c in candidates if normalize(c.title, c.author) not in read_set]
```

### 2F. Author Blacklist Filter

```python
avoid_authors = {
    "M.R. Carey",
    "Martha Wells",
    "Cassandra Clare",
    "Becky Chambers",
    "Frank Herbert",
    "Patrick Rothfuss",
    "James Islington",
    "Liu Cixin"
}

candidates = [c for c in candidates if c.author not in avoid_authors]
```

---

## Stage 3: Review Analysis

### 3A. Goodreads Review Scraping

For each top candidate (by score), fetch reviews from multiple star ratings:

**Target Reviews**:
- 2-3 five-star reviews (what fans love)
- 2-3 three-star reviews (balanced takes, often most informative)
- 2-3 one-star reviews (what critics hate — check against user's hates)

**Scraping Approaches**:

There are two scrapers available:

1. **Default (aiohttp)**: Fast (~1s/book) but only gets the ~30 reviews initially loaded on the page, heavily biased toward 5-star reviews.

2. **Playwright**: Slower (~5-10s/book) but can filter reviews by star rating by clicking the rating histogram bars in the UI. Use this when you need balanced reviews across star ratings.

```python
# Playwright scraper for filtered reviews
from recommend.scrape_playwright import scrape_reviews_for_book

reviews = scrape_reviews_for_book(
    goodreads_id="54493401",
    target_stars=[5, 3, 1],
    reviews_per_rating=3,
)
# Returns: {"5_star": [...], "3_star": [...], "1_star": [...]}
```

The Playwright scraper works by:
1. Loading the book page in headless Chromium
2. Clicking `[data-testid="ratingBar-N"]` (histogram bars) to filter by rating
3. Extracting reviews from the filtered view

**Rate Limiting**:
- 1-2 second delay between requests
- Max 5 concurrent requests (aiohttp only; Playwright is sequential)

### 3B. Review Theme Extraction

For each book's collected reviews, use LLM to extract themes:

```
Prompt:
Given these reviews for "{title}" by {author}, extract:

1. PRAISED FOR (themes from 4-5 star reviews):
   - [list themes]

2. CRITICIZED FOR (themes from 1-2 star reviews):
   - [list themes]

3. DIVISIVE ELEMENTS (mentioned both positively and negatively):
   - [list themes]

Reviews:
{reviews}
```

### 3C. Hate-Pattern Matching

Check extracted themes against user's hate list:

```python
hate_patterns = [
    "characters acting against their nature for plot",
    "smart characters written dumb",
    "internal inconsistency",
    "plot holes",
    "manufactured conflict",
    "told not shown",
    "virtue signaling",
    "over-explanation",
    "hand-holding",
    "telegraphed twists",
    "convenient plot devices",
    "philosophy over characters",
    "erratic power levels",
    "deaths that don't stick",
    "miscommunication conflict",
    "anti-technology themes",
    "modern commentary shoehorned in",
    "female characters as sex objects only",
    "one-dimensional characters",
    "author preaching through characters"
]

def check_hate_patterns(criticism_themes, hate_patterns):
    """Return list of matching hate patterns with confidence"""
    matches = []
    for theme in criticism_themes:
        for pattern in hate_patterns:
            if semantic_similarity(theme, pattern) > 0.7:
                matches.append((pattern, theme))
    return matches
```

---

## Stage 4: LLM Filtering

### 4A. Individual Book Assessment

For each candidate with scraped reviews:

```
Prompt:
You are evaluating whether a specific reader would enjoy this book.

## Reader Profile (abbreviated)

**Loves**:
- Immersion: thrown into weird worlds head first, creeping revelation
- Authorial trust: doesn't hold your hand, suggestive rather than explicit
- Character consistency: actions match personality, feel real not caricatures
- Structure: ambiguous or satisfying endings, good suspense/tension
- Writing quality: mastery of language, words as craft
- Emotional impact: books that make them cry, dark stories
- Magic systems: well-considered, clear limits

**Hates (dealbreakers)**:
- Characters acting against nature for plot
- "Smart" characters written dumb
- Internal inconsistency / plot holes
- Told not shown
- Virtue signaling
- Over-explanation / hand-holding
- Telegraphed twists
- Miscommunication conflict
- Author preaching through characters

**Genre Affinities**:
- Science Fiction: High (loves hard SF with good characters)
- Fantasy: Very High (epic fantasy, literary fantasy)
- Literary Fiction: Very High
- Short Stories: Very High
- LitRPG: Medium (guilty pleasure, won't recommend but enjoys)
- Romance: Low-Medium (skeptical but surprisable)
- YA: Low (skeptical but can be surprised)

## Book Under Evaluation

**Title**: {title}
**Author**: {author}
**Genres**: {genres}

**What fans praise** (from 5-star reviews):
{praise_themes}

**What critics dislike** (from 1-star reviews):
{criticism_themes}

**Balanced takes** (from 3-star reviews):
{balanced_themes}

**Sample Reviews**:
{sample_reviews}

## Task

1. Would this reader likely enjoy this book? (High / Medium / Low confidence)
2. What aspects align with their loves?
3. What aspects might trigger their hates?
4. Any dealbreakers present?
5. Final recommendation: (Strongly Recommend / Recommend / Maybe / Skip)

Be specific and reference the reader's documented preferences.
```

### 4B. Confidence Tiers

Based on LLM assessment, sort into tiers:

```
HIGH CONFIDENCE (Strongly Recommend):
- Multiple love-list matches
- No hate-list matches
- From favorite author OR multiple S-tier sources
- Genre affinity: High or Very High

MEDIUM CONFIDENCE (Recommend):
- Some love-list matches
- Minor hate-list concerns (not dealbreakers)
- Single S-tier source
- Genre affinity: Medium or higher

WORTH A TRY (Maybe):
- Few love-list matches OR
- Some hate-list concerns but strong genre fit
- Style-based search origin (less direct connection)
- Could go either way

SKIP:
- Dealbreaker hate-list match
- Multiple hate-list concerns
- Low genre affinity
- Author on avoid list (should be pre-filtered)
```

---

## Stage 5: Final Output

### Output Format

```markdown
# Book Recommendations

Generated: {date}
Based on: {count} S-tier favorites, {count} favorite authors

---

## High Confidence

### 1. {Title} by {Author}
**Why**: {1-2 sentence reasoning}
**Source**: Similar to {S-tier book} | By favorite author {name}
**Genre**: {genres}
**Potential concerns**: {any minor notes}

### 2. ...

---

## Medium Confidence

### 1. {Title} by {Author}
**Why**: {reasoning}
**Source**: {source}
**Caveat**: {what to watch for}

---

## Worth a Try

### 1. {Title} by {Author}
**Why it might work**: {reasoning}
**Why it might not**: {concerns}
**Source**: {source}

---

## Skipped (with reasons)

| Title | Author | Reason Skipped |
|-------|--------|----------------|
| ... | ... | Dealbreaker: {hate pattern} |
```

---

## Data Library

The data library is a persistent cache of all scraped and computed data. Once we fetch information about a book, we never need to fetch it again. The library is designed for:

1. **Incremental updates** - Add new candidates without re-processing existing ones
2. **Easy querying** - Check if we have data for a book in O(1)
3. **Extensibility** - Add new fields without breaking existing data
4. **Human readability** - JSON files that can be inspected manually

### Directory Structure

```
book-recommendations/
├── library/
│   ├── index.json              # Master index: goodreads_id → file location
│   ├── books/
│   │   ├── 17572327.json       # One file per book, named by goodreads_id
│   │   ├── 12851913.json
│   │   └── ...
│   └── searches/
│       ├── similar/            # Cached search results
│       │   ├── roadside_picnic.json
│       │   └── ...
│       ├── authors/
│       │   ├── ted_chiang.json
│       │   └── ...
│       └── style/
│           ├── immersive_worldbuilding.json
│           └── ...
```

### Book Record Schema

Each book gets a single JSON file containing all data we've collected:

```python
# library/books/{goodreads_id}.json
{
    # === IDENTITY (immutable once set) ===
    "goodreads_id": "17572327",
    "title": "The Name of the Wind",
    "author": "Patrick Rothfuss",
    "goodreads_url": "https://www.goodreads.com/book/show/17572327",

    # === SERIES INFO ===
    "series": {
        "name": "The Kingkiller Chronicle",
        "position": 1,
        "total_books": 3,
        "series_id": "12345"
    },  # null if standalone

    # === METADATA (fetched from Goodreads) ===
    "metadata": {
        "fetched_at": "2026-01-01T12:00:00Z",
        "genres": ["Fantasy", "Fiction", "Epic Fantasy"],
        "avg_rating": 4.52,
        "num_ratings": 982341,
        "num_pages": 662,
        "publication_year": 2007,
        "description": "..."
    },

    # === REVIEWS (scraped) ===
    "reviews": {
        "fetched_at": "2026-01-01T12:00:00Z",
        "five_star": [
            {
                "text": "...",
                "likes": 42,
                "date": "2024-03-15"
            }
        ],
        "three_star": [...],
        "one_star": [...]
    },

    # === ANALYSIS (LLM-generated) ===
    "analysis": {
        "generated_at": "2026-01-01T12:00:00Z",
        "model": "claude-3-opus",
        "themes": {
            "praised_for": ["prose quality", "world-building", "magic system"],
            "criticized_for": ["slow pacing", "purple prose", "unreliable release schedule"],
            "divisive": ["detailed descriptions", "first-person narration"]
        },
        "hate_pattern_matches": [
            {
                "pattern": "self-indulgent male fantasy",
                "evidence": "Multiple reviewers mention...",
                "confidence": 0.85
            }
        ]
    },

    # === RECOMMENDATION STATUS ===
    "recommendation": {
        "generated_at": "2026-01-01T12:00:00Z",
        "sources": [
            {"type": "similar", "seed": "A Wizard of Earthsea"},
            {"type": "style", "query": "fantasy prose quality"}
        ],
        "frequency_score": 3.2,
        "tier": "skip",  # high / medium / try / skip
        "reasoning": "Multiple hate-pattern matches including...",
        "dealbreakers": ["self-indulgent male fantasy"]
    }
}
```

### Index Schema

The index allows fast lookups without loading all book files:

```python
# library/index.json
{
    "version": 1,
    "last_updated": "2026-01-01T12:00:00Z",
    "books": {
        "17572327": {
            "title": "The Name of the Wind",
            "author": "Patrick Rothfuss",
            "has_metadata": true,
            "has_reviews": true,
            "has_analysis": true,
            "has_recommendation": true,
            "tier": "skip"
        },
        "12851913": {
            "title": "Roadside Picnic",
            "author": "Arkady Strugatsky",
            "has_metadata": true,
            "has_reviews": false,  # Not yet scraped
            "has_analysis": false,
            "has_recommendation": false,
            "tier": null
        }
    },
    "already_read": ["17572327", "12851913", ...]  # List of goodreads_ids we've read
}
```

### Library API

```python
# library.py

class BookLibrary:
    """Interface for the book data library."""

    def __init__(self, path: Path = Path("library")):
        self.path = path
        self.index = self._load_index()

    # === QUERIES ===

    def has_book(self, goodreads_id: str) -> bool:
        """Check if we have any data for this book."""
        return goodreads_id in self.index["books"]

    def has_reviews(self, goodreads_id: str) -> bool:
        """Check if we've scraped reviews for this book."""
        return self.index["books"].get(goodreads_id, {}).get("has_reviews", False)

    def has_analysis(self, goodreads_id: str) -> bool:
        """Check if we've analyzed this book."""
        return self.index["books"].get(goodreads_id, {}).get("has_analysis", False)

    def is_already_read(self, goodreads_id: str) -> bool:
        """Check if this book is in the already-read list."""
        return goodreads_id in self.index["already_read"]

    def get_book(self, goodreads_id: str) -> Optional[dict]:
        """Load full book record from disk."""
        path = self.path / "books" / f"{goodreads_id}.json"
        if path.exists():
            return json.loads(path.read_text())
        return None

    def get_books_needing_reviews(self) -> list[str]:
        """Return goodreads_ids of books that need review scraping."""
        return [
            gid for gid, info in self.index["books"].items()
            if info.get("has_metadata") and not info.get("has_reviews")
        ]

    def get_books_needing_analysis(self) -> list[str]:
        """Return goodreads_ids of books that have reviews but no analysis."""
        return [
            gid for gid, info in self.index["books"].items()
            if info.get("has_reviews") and not info.get("has_analysis")
        ]

    # === UPDATES ===

    def add_candidate(self, goodreads_id: str, title: str, author: str,
                      sources: list[dict]) -> None:
        """Add a new candidate to the library (minimal info)."""
        if goodreads_id in self.index["books"]:
            # Merge sources with existing
            book = self.get_book(goodreads_id)
            existing_sources = book.get("recommendation", {}).get("sources", [])
            book.setdefault("recommendation", {})["sources"] = existing_sources + sources
            self._save_book(goodreads_id, book)
        else:
            book = {
                "goodreads_id": goodreads_id,
                "title": title,
                "author": author,
                "recommendation": {"sources": sources}
            }
            self._save_book(goodreads_id, book)
            self.index["books"][goodreads_id] = {
                "title": title,
                "author": author,
                "has_metadata": False,
                "has_reviews": False,
                "has_analysis": False,
                "has_recommendation": False,
                "tier": None
            }
            self._save_index()

    def add_metadata(self, goodreads_id: str, metadata: dict) -> None:
        """Add metadata to an existing book record."""
        book = self.get_book(goodreads_id)
        book["metadata"] = {**metadata, "fetched_at": datetime.utcnow().isoformat()}
        self._save_book(goodreads_id, book)
        self.index["books"][goodreads_id]["has_metadata"] = True
        self._save_index()

    def add_reviews(self, goodreads_id: str, reviews: dict) -> None:
        """Add scraped reviews to an existing book record."""
        book = self.get_book(goodreads_id)
        book["reviews"] = {**reviews, "fetched_at": datetime.utcnow().isoformat()}
        self._save_book(goodreads_id, book)
        self.index["books"][goodreads_id]["has_reviews"] = True
        self._save_index()

    def add_analysis(self, goodreads_id: str, analysis: dict) -> None:
        """Add LLM analysis to an existing book record."""
        book = self.get_book(goodreads_id)
        book["analysis"] = {
            **analysis,
            "generated_at": datetime.utcnow().isoformat()
        }
        self._save_book(goodreads_id, book)
        self.index["books"][goodreads_id]["has_analysis"] = True
        self._save_index()

    def set_recommendation(self, goodreads_id: str, tier: str,
                           reasoning: str, dealbreakers: list[str]) -> None:
        """Set final recommendation for a book."""
        book = self.get_book(goodreads_id)
        book.setdefault("recommendation", {}).update({
            "generated_at": datetime.utcnow().isoformat(),
            "tier": tier,
            "reasoning": reasoning,
            "dealbreakers": dealbreakers
        })
        self._save_book(goodreads_id, book)
        self.index["books"][goodreads_id]["has_recommendation"] = True
        self.index["books"][goodreads_id]["tier"] = tier
        self._save_index()

    # === INTERNAL ===

    def _save_book(self, goodreads_id: str, book: dict) -> None:
        path = self.path / "books" / f"{goodreads_id}.json"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(book, indent=2))

    def _save_index(self) -> None:
        self.index["last_updated"] = datetime.utcnow().isoformat()
        (self.path / "index.json").write_text(json.dumps(self.index, indent=2))

    def _load_index(self) -> dict:
        path = self.path / "index.json"
        if path.exists():
            return json.loads(path.read_text())
        return {"version": 1, "books": {}, "already_read": []}
```

### Search Result Caching

Search results are cached separately so we can re-run candidate generation without hitting the web:

```python
# library/searches/similar/roadside_picnic.json
{
    "query": "books similar to Roadside Picnic",
    "searched_at": "2026-01-01T12:00:00Z",
    "results": [
        {"title": "Solaris", "author": "Stanislaw Lem", "goodreads_id": "95558"},
        {"title": "Annihilation", "author": "Jeff VanderMeer", "goodreads_id": "17934530"},
        ...
    ]
}
```

### Incremental Pipeline

With the library in place, each pipeline stage becomes incremental:

```bash
# Only searches for S-tier books we haven't searched yet
uv run python -m recommend search-similar

# Only scrapes reviews for books that don't have them
uv run python -m recommend scrape-reviews

# Only analyzes books that have reviews but no analysis
uv run python -m recommend analyze

# Re-runs recommendations for all analyzed books (uses cached data)
uv run python -m recommend recommend
```

### Adding New Data Later

To add more reviews to existing books:

```python
def add_more_reviews(library: BookLibrary, goodreads_id: str, star_rating: int):
    """Fetch additional reviews for a specific star rating."""
    book = library.get_book(goodreads_id)
    existing = book.get("reviews", {}).get(f"{star_rating}_star", [])

    # Scrape more reviews, skipping ones we already have
    new_reviews = scrape_reviews(goodreads_id, star_rating, skip=len(existing))

    # Append to existing
    book["reviews"][f"{star_rating}_star"] = existing + new_reviews
    book["reviews"]["fetched_at"] = datetime.utcnow().isoformat()
    library._save_book(goodreads_id, book)
```

To re-analyze with different criteria:

```python
def reanalyze_with_new_criteria(library: BookLibrary, new_hate_patterns: list[str]):
    """Re-run analysis for all books with new hate patterns."""
    for goodreads_id in library.get_books_with_reviews():
        book = library.get_book(goodreads_id)
        reviews = book["reviews"]

        # Run new analysis
        new_analysis = analyze_reviews(reviews, hate_patterns=new_hate_patterns)

        # Store with version info
        book["analysis"] = {
            **new_analysis,
            "generated_at": datetime.utcnow().isoformat(),
            "hate_patterns_version": hash(tuple(new_hate_patterns))
        }
        library._save_book(goodreads_id, book)
```

### Migration Support

When the schema changes, add a migration:

```python
# migrations/001_add_series_info.py
def migrate(library_path: Path):
    """Add series info field to all books."""
    for book_file in (library_path / "books").glob("*.json"):
        book = json.loads(book_file.read_text())
        if "series" not in book:
            book["series"] = None  # Will be populated on next metadata fetch
            book_file.write_text(json.dumps(book, indent=2))
```

---

## Implementation Plan

### Phase 1: Candidate Generation Script
```
recommend/
├── __init__.py
├── search.py          # Web search utilities
├── candidates.py      # Candidate compilation and scoring
└── cli.py             # Command-line interface
```

**Commands**:
```bash
# Generate candidates from S-tier books
uv run python -m recommend search-similar

# Find unread books by favorite authors
uv run python -m recommend search-authors

# Run style-based searches
uv run python -m recommend search-style
```

### Phase 2: Review Scraping
```
recommend/
├── scrape.py          # Goodreads review scraper
└── themes.py          # LLM-based theme extraction
```

**Commands**:
```bash
# Scrape reviews for top N candidates
uv run python -m recommend scrape-reviews --top 50

# Extract themes from reviews
uv run python -m recommend extract-themes
```

### Phase 3: Filtering and Output
```
recommend/
├── filter.py          # LLM filtering against profile
└── output.py          # Generate final recommendations
```

**Commands**:
```bash
# Run LLM filtering
uv run python -m recommend filter

# Generate final report
uv run python -m recommend report
```

### Full Pipeline
```bash
# Run everything
uv run python -m recommend full-pipeline --top 50
```

---

## Data Files

```
book-recommendations/
├── data/
│   └── read_books_with_genres.csv    # Already-read books (input, from Goodreads export)
├── library/                          # Persistent cache (see Data Library section)
│   ├── index.json
│   ├── books/
│   └── searches/
├── output/
│   └── recommendations.md            # Final output
└── user_profile.md                   # Reader preferences (input)
```

See the **Data Library** section for full details on the caching system.

---

## Configuration

```python
# config.py

# Search settings
SIMILAR_BOOK_SEARCHES_PER_FAVORITE = 2
MAX_STYLE_SEARCHES = 10

# Candidate settings
MIN_FREQUENCY_SCORE = 1
TOP_CANDIDATES_FOR_REVIEW = 50

# Scraping settings
REVIEWS_PER_STAR_RATING = 3
SCRAPE_DELAY_SECONDS = 1.5
MAX_CONCURRENT_REQUESTS = 5

# Filtering settings
DEALBREAKER_SIMILARITY_THRESHOLD = 0.7

# Authors
AVOID_AUTHORS = [
    "M.R. Carey",
    "Martha Wells",
    "Cassandra Clare",
    "Becky Chambers",
    "Frank Herbert",
    "Patrick Rothfuss",
    "James Islington",
    "Liu Cixin"
]

FAVORITE_AUTHORS = [
    "Ted Chiang",
    "Ken Liu",
    "Ursula K. Le Guin",
    # ... etc
]
```

---

## Refinements for Future Iterations

1. **Feedback Loop**: Track which recommendations were actually read and rated. Use this to tune scoring weights. Add a `feedback` field to book records.

2. **Recency Weighting**: Boost books published in last 2-3 years for discovering new authors.

3. **Goodreads "Also Enjoyed" Scraping**: As a complement to web search, scrape the "Readers also enjoyed" section directly from book pages.

4. **Review Quality Filtering**: Some Goodreads reviews are low-quality. Filter for reviews with 10+ "likes" or minimum word count.

5. **Narrator Check**: For audiobook preferences, cross-reference narrator against loved/hated narrators list from user profile.

6. **Collaborative Filtering**: Find Goodreads users who also rated S-tier books highly, see what else they recommend.

7. **Award-Based Discovery**: Pull Hugo/Nebula/World Fantasy winners and cross-reference against profile.
