# Anime User Profile Research Guide

## Goal

Extract a comprehensive user preference profile from `watched.csv` to enable accurate anime recommendations. The profile should capture what makes this viewer unique—their loves, hates, and quirks.

## Methodology

### Process

1. **Work in chunks** - Process ~25 shows at a time from the spreadsheet
2. **Update incrementally** - After each chunk, update `user_profile.md`
3. **Extract signals** - Look for explicit statements and implicit patterns
4. **Preserve nuance** - Don't flatten complex opinions into simple categories

### What to Extract

For each review, identify:

**Explicit Signals** (stated directly)
- "favorite", "loved", "hated", "worst"
- "would recommend" / "wouldn't recommend"
- "would watch again" / "wouldn't watch again"
- Specific praise or criticism

**Implicit Signals** (inferred from patterns)
- What makes them keep watching vs drop a show
- What triggers emotional responses (crying, staying up late)
- Recurring complaints across multiple shows
- What they forgive vs what kills a show

### Profile Categories

#### 1. Tier Lists

**S-Tier (Favorites)**
- Explicitly called "favorite" or "top 10"
- Would watch again, eager to recommend
- Strong emotional impact

**A-Tier (Loved)**
- Strong positive review
- Would recommend
- Memorable

**F-Tier (Hated)**
- Explicitly negative
- Would not recommend
- Dropped or regretted watching

#### 2. What They Love

Elements that consistently lead to positive reviews:
- Thematic (emotional depth, dark themes, psychological complexity)
- Structural (good pacing, earned payoffs, consistent logic)
- Character (strong development, believable motivations)
- Technical (animation quality, art style, music)

#### 3. What They Hate

Elements that consistently lead to negative reviews or drops:
- Deal-breakers (things that ruin otherwise good shows)
- Pet peeves (annoying but tolerable)
- Red flags (patterns that predict dislike)

#### 4. Tolerance Levels

How much of X will they put up with?
- Fanservice
- Plot holes / unrealistic elements
- Slow pacing
- Harem tropes
- Happy endings when sad would fit

#### 5. Ending Preferences

Strong opinions on how shows should end:
- Preference for sad/bittersweet vs happy
- Hate for "cop-out" endings
- What makes an ending earned vs contrived

#### 6. Character Archetypes

Loved:
- (Extract from reviews)

Hated:
- Weak female leads needing rescue
- Overpowered protagonists who are boring
- (Extract more)

#### 7. Genre Affinities

Which genres consistently score well/poorly?
- Track success rate by genre tag

#### 8. Recommendation Contexts

Different tiers of recommendation:
- "Universal recommendation" - would show anyone
- "Anime fans only" - good but requires context
- "Specific audience" - good for the right person
- "Personal guilty pleasure" - enjoyed but wouldn't recommend

### Already Seen List

Maintain a clean list of all titles watched for filtering recommendations.

## Output Files

- `user_profile.md` - The profile (updated incrementally)
- `requirements.md` - Original context (already exists)
- `watched.csv` - Source data (read-only)

## Quality Checks

After processing all chunks:
1. Review for contradictions
2. Consolidate redundant entries
3. Identify strongest patterns
4. Note edge cases and exceptions
