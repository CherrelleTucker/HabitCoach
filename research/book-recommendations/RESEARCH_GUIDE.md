# Book User Profile Research Guide

## Goal

Extract a comprehensive user preference profile from `read_books_with_genres.csv` to enable accurate book recommendations. The profile should capture what makes this reader unique—their loves, hates, and quirks—split between fiction and non-fiction.

---

## Rating System

**Critical**: This reader is stingy with stars. Interpret ratings as follows:

| Rating | Meaning | Profile Action |
|--------|---------|----------------|
| **5** | All-time favorite, loved | S-Tier |
| **4** | Absolutely worth reading, liked a lot | A-Tier |
| **3** | Average, mix of good/bad, or good but wouldn't recommend. **NOT negative.** | Note patterns, not a dislike |
| **2** | Trash | F-Tier |
| **1** | Trash | F-Tier |
| **0 (unrated)** | Unknown opinion—only indicates subject interest | Track for genre/topic affinity only |

**Important distinctions:**
- A 3-star book is not a failure. It may have been enjoyable but flawed, or good but niche.
- Unrated books should NOT be used to infer quality opinions—only to understand what subjects/genres attract interest.
- The gap between 4 and 5 is significant. 4 is "great", 5 is "life-changing".

---

## Methodology

### Process

1. **Split by type** - Process fiction and non-fiction separately
2. **Work in chunks** - Process ~25 books at a time from the spreadsheet
3. **Update incrementally** - After each chunk, update `user_profile.md`
4. **Extract signals** - Look for explicit statements and implicit patterns
5. **Preserve nuance** - Don't flatten complex opinions into simple categories

### Filtering

```
- Rated 1-5: Use for preference extraction
- Rated 0 (unrated): Use ONLY for topic/genre interest tracking
- Has review: Primary source of preference signals
- No review: Use rating + genre only
```

### What to Extract

For each reviewed book, identify:

**Explicit Signals** (stated directly)
- "favorite", "loved", "hated", "worst"
- "would recommend" / "wouldn't recommend"
- "would read again" / specific audience recommendations
- Specific praise or criticism
- Comparisons to other books/authors

**Implicit Signals** (inferred from patterns)
- What makes them keep reading vs DNF
- What triggers emotional responses (crying, staying up late, thinking about it)
- Recurring complaints across multiple books
- What they forgive vs what kills a book
- Author/series trajectory opinions

---

## Profile Categories

> **Note**: All preferences must be discovered organically from the book reviews. Do NOT import assumptions from anime/movie preferences. Categories below are templates to guide extraction—fill them only with evidence from the book data.

### Split Structure

The profile should have parallel structures for **Fiction** and **Non-Fiction**, with some shared categories.

```
user_profile.md
├── Rating Philosophy (shared)
├── Fiction
│   ├── Tier Lists
│   ├── What They Love
│   ├── What They Hate
│   ├── Tolerance Levels
│   ├── Ending Preferences
│   ├── Character Preferences
│   ├── Genre Affinities
│   ├── Author Affinities
│   ├── Series Behavior
│   └── Already Read
└── Non-Fiction
    ├── Tier Lists
    ├── What They Love
    ├── What They Hate
    ├── Writing Style Preferences
    ├── Topic Affinities
    ├── Author Affinities
    └── Already Read
├── Format Preferences (shared - audiobooks, narrators)
├── Reading Patterns (shared)
└── Recommendation Contexts (shared)
```

---

### Tier Lists

**S-Tier (5 stars + strong language)**
- Explicitly called "favorite" or "best"
- Would read again, eager to recommend
- Strong emotional impact
- Life-changing or perspective-shifting

**A-Tier (4 stars)**
- Strong positive review
- Would recommend (possibly to specific audiences)
- Memorable and worthwhile

**B-Tier (3 stars) - Track patterns, not failures**
- Note what worked and what didn't
- Identify "good but wouldn't recommend" patterns
- These reveal tolerance levels and edge cases

**F-Tier (1-2 stars)**
- Explicitly negative
- Would not recommend
- Dropped or regretted reading

---

### What They Love

*Discover organically from reviews. Suggested categories to look for:*

#### Fiction
- **Emotional Impact** - (extract from reviews)
- **Internal Consistency** - (extract from reviews)
- **Character Depth** - (extract from reviews)
- **Earned Payoffs** - (extract from reviews)
- **Writing Quality** - (extract from reviews)
- **Thematic Depth** - (extract from reviews)

#### Non-Fiction
- **Readability** - (extract from reviews)
- **Narrative Quality** - (extract from reviews)
- **Research Depth** - (extract from reviews)
- **Novel Insights** - (extract from reviews)
- **Author Expertise** - (extract from reviews)

---

### What They Hate

*Discover organically from reviews. Suggested categories:*

#### Deal-Breakers
*Elements that can ruin an otherwise good book*

- (extract from reviews)

#### Pet Peeves
*Annoying but tolerable*

- (extract from reviews)

#### Red Flags
*Patterns that predict dislike*

- (extract from reviews)

---

### Tolerance Levels

*Discover organically from reviews. Suggested elements to track:*

| Element | Tolerance | Notes |
|---------|-----------|-------|
| Slow pacing | ? | (extract from reviews) |
| Dense writing | ? | (extract from reviews) |
| Unrealistic elements | ? | (extract from reviews) |
| Heavy-handed themes | ? | (extract from reviews) |
| Series length | ? | (extract from reviews) |
| Dated attitudes | ? | (extract from reviews) |
| Romance/relationships | ? | (extract from reviews) |

---

### Ending Preferences

*Discover organically from reviews.*

#### Preferred
- (extract from reviews)

#### Hated
- (extract from reviews)

---

### Character Preferences

*Discover organically from reviews.*

#### Loved
- (extract from reviews)

#### Hated
- (extract from reviews)

---

### Genre Affinities

Track success rate by genre. Genres come from Goodreads tags (pipe-separated in CSV).

#### Fiction Genres to Track
- Science Fiction
- Fantasy (High, Urban, etc.)
- Literary Fiction
- Historical Fiction
- Mystery/Thriller
- Romance/Romantasy
- Horror

#### Non-Fiction Genres to Track
- History
- Science
- Biography/Memoir
- Philosophy
- Economics/Politics
- Anthropology/Evolution

---

### Author Affinities

**Track:**
- Favorite authors (multiple high-rated books)
- Authors to avoid (multiple low-rated books)
- Author growth/decline across works
- "Would read more from this author"

---

### Series Behavior

- When does series fatigue set in?
- Short stories vs novels within series
- Declining quality tolerance
- Completion compulsion vs willingness to quit

---

### Format Preferences

**Audiobooks:**
- Narrator quality matters significantly
- Pronunciation issues (especially non-English names)
- Narrator style preferences
- When audio enhances vs detracts

---

### Reading Patterns

*Discover organically from reviews.*

#### What Makes Them Binge
- (extract from reviews)

#### What Makes Them DNF
- (extract from reviews)

#### Disappointment Pattern
- (extract from reviews)

---

### Recommendation Contexts

#### Universal Recommendation
*Would recommend to anyone*

#### Genre Fans Only
*Good but requires context/familiarity*

#### Specific Audience
*Great for the right person*

#### Heavy Caveats
*Enjoyed but wouldn't recommend*

---

## Output Files

- `user_profile.md` - The profile (updated incrementally)
- `RESEARCH_GUIDE.md` - This document
- `data/read_books_with_genres.csv` - Source data (read-only)

---

## Quality Checks

After processing all chunks:
1. Review for contradictions
2. Consolidate redundant entries
3. Identify strongest patterns
4. Note edge cases and exceptions
5. Ensure fiction/non-fiction separation is maintained
6. Verify unrated books only used for topic interest

---

## Processing Log Template

| Chunk | Type | Books | Date | Notes |
|-------|------|-------|------|-------|
| 1 | Fiction | 1-25 | | |
| 2 | Fiction | 26-50 | | |
| ... | | | | |
| N | Non-Fiction | 1-25 | | |
