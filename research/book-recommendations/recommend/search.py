"""Web search utilities using DuckDuckGo."""

import re
import time
from dataclasses import dataclass
from typing import Optional

from ddgs import DDGS

from .config import SEARCH_MAX_RESULTS
from .library import BookLibrary


@dataclass
class SearchResult:
    """A single search result."""

    title: str
    url: str
    snippet: str
    extracted_book: Optional[str] = None
    extracted_author: Optional[str] = None


def slugify(text: str) -> str:
    """Convert text to a filename-safe slug."""
    # Lowercase, replace spaces with underscores, remove non-alphanumeric
    slug = text.lower().strip()
    slug = re.sub(r"[^\w\s-]", "", slug)
    slug = re.sub(r"[\s_-]+", "_", slug)
    return slug[:100]  # Limit length


def execute_search(query: str, max_results: int = SEARCH_MAX_RESULTS) -> list[SearchResult]:
    """
    Execute a DuckDuckGo search and return results.

    Args:
        query: The search query
        max_results: Maximum number of results to return

    Returns:
        List of SearchResult objects
    """
    results = []

    with DDGS() as ddgs:
        for r in ddgs.text(query, max_results=max_results):
            result = SearchResult(
                title=r.get("title", ""),
                url=r.get("href", ""),
                snippet=r.get("body", ""),
            )

            # Try to extract book/author info from the result
            book, author = extract_book_author(result.title, result.snippet)
            result.extracted_book = book
            result.extracted_author = author

            results.append(result)

    return results


def extract_book_author(title: str, snippet: str) -> tuple[Optional[str], Optional[str]]:
    """
    Try to extract book title and author from search result.

    Looks for common patterns like:
    - "Book Title by Author Name"
    - "Author Name - Book Title"
    - Goodreads-style "Book Title (Series #1) by Author"

    Returns:
        Tuple of (book_title, author) or (None, None) if not found
    """
    text = f"{title} {snippet}"

    # Pattern: "Title by Author"
    by_pattern = re.search(
        r'"?([^"]+)"?\s+by\s+([A-Z][a-zA-Z\.\s]+?)(?:\s*[-–—]|\s*\||\s*$)',
        text,
        re.IGNORECASE,
    )
    if by_pattern:
        book = by_pattern.group(1).strip().strip('"')
        author = by_pattern.group(2).strip()
        # Clean up series notation
        book = re.sub(r"\s*\([^)]*#\d+[^)]*\)", "", book)
        return book, author

    # Pattern: "Author - Title" or "Author: Title"
    author_first = re.search(
        r"([A-Z][a-zA-Z\.\s]+?)\s*[-–—:]\s*([^,\|]+)",
        text,
    )
    if author_first:
        author = author_first.group(1).strip()
        book = author_first.group(2).strip().strip('"')
        # Only accept if author looks like a name (2-4 words)
        words = author.split()
        if 2 <= len(words) <= 4:
            return book, author

    return None, None


def search_similar_books(
    library: BookLibrary,
    seed_title: str,
    seed_author: str,
    delay: float = 1.0,
) -> list[dict]:
    """
    Search for books similar to a seed book.

    Caches results to avoid re-searching.

    Args:
        library: BookLibrary instance for caching
        seed_title: Title of the seed book
        seed_author: Author of the seed book
        delay: Seconds to wait between searches

    Returns:
        List of search results with extracted book info
    """
    queries = [
        f'books similar to "{seed_title}"',
        f'books like "{seed_title}" by {seed_author}',
    ]

    all_results = []
    search_type = "similar"

    for query in queries:
        slug = slugify(f"{seed_title}_{query[:30]}")

        # Check cache first
        cached = library.get_cached_search(search_type, slug)
        if cached:
            all_results.extend(cached["results"])
            continue

        # Execute search
        results = execute_search(query)
        result_dicts = [
            {
                "title": r.title,
                "url": r.url,
                "snippet": r.snippet,
                "extracted_book": r.extracted_book,
                "extracted_author": r.extracted_author,
            }
            for r in results
        ]

        # Cache results
        library.cache_search(search_type, slug, query, result_dicts)
        all_results.extend(result_dicts)

        time.sleep(delay)

    return all_results


def search_author_books(
    library: BookLibrary,
    author: str,
    delay: float = 1.0,
) -> list[dict]:
    """
    Search for books by a specific author.

    Args:
        library: BookLibrary instance for caching
        author: Author name to search for
        delay: Seconds to wait between searches

    Returns:
        List of search results
    """
    queries = [
        f"{author} books list",
        f"best {author} books",
    ]

    all_results = []
    search_type = "author"

    for query in queries:
        slug = slugify(f"{author}_{query[:20]}")

        # Check cache
        cached = library.get_cached_search(search_type, slug)
        if cached:
            all_results.extend(cached["results"])
            continue

        results = execute_search(query)
        result_dicts = [
            {
                "title": r.title,
                "url": r.url,
                "snippet": r.snippet,
                "extracted_book": r.extracted_book,
                "extracted_author": r.extracted_author,
            }
            for r in results
        ]

        library.cache_search(search_type, slug, query, result_dicts)
        all_results.extend(result_dicts)

        time.sleep(delay)

    return all_results


def search_by_style(
    library: BookLibrary,
    style_query: str,
    delay: float = 1.0,
) -> list[dict]:
    """
    Search for books matching a style description.

    Args:
        library: BookLibrary instance for caching
        style_query: Style-based search query (e.g., "fantasy immersive worldbuilding")
        delay: Seconds to wait between searches

    Returns:
        List of search results
    """
    queries = [
        f"best {style_query} books",
        f"{style_query} book recommendations",
    ]

    all_results = []
    search_type = "style"

    for query in queries:
        slug = slugify(query)

        cached = library.get_cached_search(search_type, slug)
        if cached:
            all_results.extend(cached["results"])
            continue

        results = execute_search(query)
        result_dicts = [
            {
                "title": r.title,
                "url": r.url,
                "snippet": r.snippet,
                "extracted_book": r.extracted_book,
                "extracted_author": r.extracted_author,
            }
            for r in results
        ]

        library.cache_search(search_type, slug, query, result_dicts)
        all_results.extend(result_dicts)

        time.sleep(delay)

    return all_results
