"""Candidate compilation, deduplication, and scoring."""

import csv
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

from rapidfuzz import fuzz

from .config import (
    AVOID_AUTHORS,
    FAVORITE_AUTHORS,
    FUZZY_MATCH_THRESHOLD,
    READ_BOOKS_CSV,
)


@dataclass
class Candidate:
    """A book candidate for recommendation."""

    title: str
    author: str
    goodreads_id: Optional[str] = None
    sources: list[dict] = field(default_factory=list)
    frequency_score: float = 1.0
    normalized_key: str = ""

    def __post_init__(self):
        if not self.normalized_key:
            self.normalized_key = normalize_key(self.title, self.author)


def normalize_title(title: str) -> str:
    """
    Normalize a book title for comparison.

    - Lowercase
    - Remove subtitles (everything after ":")
    - Remove series indicators like "(Book 1)"
    - Remove "The" prefix
    - Remove extra whitespace
    """
    title = title.lower().strip()

    # Remove subtitle
    title = re.sub(r":.*$", "", title)

    # Remove series indicators
    title = re.sub(r"\s*\([^)]*(?:#|book|vol|volume)\s*\d+[^)]*\)", "", title, flags=re.IGNORECASE)
    title = re.sub(r"\s*#\d+\s*$", "", title)

    # Remove "the" prefix
    title = re.sub(r"^the\s+", "", title)

    # Clean whitespace
    title = " ".join(title.split())

    return title


def normalize_author(author: str) -> str:
    """
    Normalize an author name for comparison.

    - Lowercase
    - Handle initials (J.R.R. -> jrr)
    - Remove middle names/initials
    """
    author = author.lower().strip()

    # Remove periods from initials
    author = re.sub(r"\.(?=\s|$|[A-Z])", "", author)
    author = author.replace(".", "")

    # Clean whitespace
    author = " ".join(author.split())

    return author


def normalize_key(title: str, author: str) -> str:
    """Create a normalized key for deduplication."""
    return f"{normalize_title(title)}|{normalize_author(author)}"


def are_duplicates(
    title1: str,
    author1: str,
    title2: str,
    author2: str,
    threshold: int = FUZZY_MATCH_THRESHOLD,
) -> bool:
    """
    Check if two book entries are duplicates using fuzzy matching.

    Uses token_sort_ratio for both title and author to handle
    word order variations.
    """
    norm_title1 = normalize_title(title1)
    norm_title2 = normalize_title(title2)
    norm_author1 = normalize_author(author1)
    norm_author2 = normalize_author(author2)

    # Check exact normalized match first
    if norm_title1 == norm_title2 and norm_author1 == norm_author2:
        return True

    # Fuzzy match on title
    title_score = fuzz.token_sort_ratio(norm_title1, norm_title2)
    if title_score < threshold:
        return False

    # Fuzzy match on author
    author_score = fuzz.token_sort_ratio(norm_author1, norm_author2)
    if author_score < threshold:
        return False

    return True


def deduplicate_candidates(candidates: list[Candidate]) -> list[Candidate]:
    """
    Deduplicate candidates, merging sources for duplicates.

    Uses fuzzy matching to catch near-duplicates.
    Returns list with merged frequency scores.
    """
    unique: list[Candidate] = []

    for candidate in candidates:
        found = False
        for existing in unique:
            if are_duplicates(
                candidate.title,
                candidate.author,
                existing.title,
                existing.author,
            ):
                # Merge into existing
                existing.sources.extend(candidate.sources)
                existing.frequency_score += candidate.frequency_score
                found = True
                break

        if not found:
            unique.append(candidate)

    return unique


def load_already_read(csv_path: Path = READ_BOOKS_CSV) -> set[str]:
    """
    Load already-read books as normalized keys.

    Returns set of normalized (title|author) keys.
    """
    read_books = set()

    if not csv_path.exists():
        return read_books

    with open(csv_path, encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            title = row.get("title", "")
            author = row.get("author", "")
            if title and author:
                read_books.add(normalize_key(title, author))

    return read_books


def filter_already_read(
    candidates: list[Candidate],
    read_books: Optional[set[str]] = None,
) -> list[Candidate]:
    """
    Filter out books the user has already read.

    Uses fuzzy matching against the read_books set.
    """
    if read_books is None:
        read_books = load_already_read()

    filtered = []
    for candidate in candidates:
        # Check exact match first
        if candidate.normalized_key in read_books:
            continue

        # Check fuzzy match against all read books
        is_read = False
        for read_key in read_books:
            read_title, read_author = read_key.split("|", 1)
            if are_duplicates(
                candidate.title,
                candidate.author,
                read_title,
                read_author,
                threshold=90,  # Higher threshold for read books
            ):
                is_read = True
                break

        if not is_read:
            filtered.append(candidate)

    return filtered


def filter_blacklisted_authors(
    candidates: list[Candidate],
    avoid_authors: list[str] = AVOID_AUTHORS,
) -> list[Candidate]:
    """Filter out books by blacklisted authors."""
    avoid_normalized = {normalize_author(a) for a in avoid_authors}

    return [
        c
        for c in candidates
        if normalize_author(c.author) not in avoid_normalized
    ]


def score_candidates(
    candidates: list[Candidate],
    favorite_authors: list[str] = FAVORITE_AUTHORS,
) -> list[Candidate]:
    """
    Score candidates based on frequency and other factors.

    Modifies candidates in place and returns sorted list (highest first).
    """
    favorite_normalized = {normalize_author(a) for a in favorite_authors}

    for candidate in candidates:
        score = candidate.frequency_score

        # Bonus for multiple unique S-tier sources
        stier_sources = [
            s for s in candidate.sources if s.get("type") == "similar"
        ]
        unique_seeds = set(s.get("seed", "") for s in stier_sources)
        if len(unique_seeds) >= 3:
            score *= 1.5
        elif len(unique_seeds) >= 2:
            score *= 1.2

        # Bonus for favorite author
        if normalize_author(candidate.author) in favorite_normalized:
            score *= 1.3

        candidate.frequency_score = score

    # Sort by score (descending)
    return sorted(candidates, key=lambda c: c.frequency_score, reverse=True)


def process_candidates(
    candidates: list[Candidate],
    read_books: Optional[set[str]] = None,
) -> list[Candidate]:
    """
    Run the full candidate processing pipeline:
    1. Deduplicate
    2. Filter already-read
    3. Filter blacklisted authors
    4. Score and sort

    Returns processed and sorted candidate list.
    """
    # Deduplicate
    candidates = deduplicate_candidates(candidates)

    # Filter already-read
    candidates = filter_already_read(candidates, read_books)

    # Filter blacklisted authors
    candidates = filter_blacklisted_authors(candidates)

    # Score and sort
    candidates = score_candidates(candidates)

    return candidates


def extract_candidates_from_search_results(
    search_results: list[dict],
    source: dict,
) -> list[Candidate]:
    """
    Extract book candidates from search results.

    Args:
        search_results: List of search result dicts with extracted_book/author
        source: Source info dict (e.g., {"type": "similar", "seed": "Piranesi"})

    Returns:
        List of Candidate objects
    """
    candidates = []

    for result in search_results:
        book = result.get("extracted_book")
        author = result.get("extracted_author")

        if book and author:
            candidates.append(
                Candidate(
                    title=book,
                    author=author,
                    sources=[source],
                )
            )

    return candidates
