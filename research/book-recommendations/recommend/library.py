"""Persistent data library for book recommendations.

Provides a JSON-based cache for books, searches, and metadata.
Once data is fetched, it's stored locally to avoid re-fetching.
"""

import csv
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

from .config import LIBRARY_DIR, READ_BOOKS_CSV


class BookLibrary:
    """Interface for the book data library."""

    def __init__(self, path: Path = LIBRARY_DIR):
        self.path = path
        self.books_dir = path / "books"
        self.searches_dir = path / "searches"
        self.index_path = path / "index.json"

        # Ensure directories exist
        self.books_dir.mkdir(parents=True, exist_ok=True)
        self.searches_dir.mkdir(parents=True, exist_ok=True)

        self.index = self._load_index()
        self._already_read: Optional[set[str]] = None

    # === QUERIES ===

    def has_book(self, goodreads_id: str) -> bool:
        """Check if we have any data for this book."""
        return goodreads_id in self.index["books"]

    def has_metadata(self, goodreads_id: str) -> bool:
        """Check if we've fetched metadata for this book."""
        return self.index["books"].get(goodreads_id, {}).get("has_metadata", False)

    def has_reviews(self, goodreads_id: str) -> bool:
        """Check if we've scraped reviews for this book."""
        return self.index["books"].get(goodreads_id, {}).get("has_reviews", False)

    def has_analysis(self, goodreads_id: str) -> bool:
        """Check if we've analyzed this book."""
        return self.index["books"].get(goodreads_id, {}).get("has_analysis", False)

    def is_already_read(self, goodreads_id: str) -> bool:
        """Check if this book is in the already-read list."""
        if self._already_read is None:
            self._already_read = self._load_already_read()
        return goodreads_id in self._already_read

    def get_book(self, goodreads_id: str) -> Optional[dict]:
        """Load full book record from disk."""
        path = self.books_dir / f"{goodreads_id}.json"
        if path.exists():
            return json.loads(path.read_text())
        return None

    def get_all_books(self) -> list[dict]:
        """Load all book records from disk."""
        books = []
        for gid in self.index["books"]:
            book = self.get_book(gid)
            if book:
                books.append(book)
        return books

    def get_books_needing_metadata(self) -> list[str]:
        """Return goodreads_ids of books that need metadata fetching."""
        return [
            gid
            for gid, info in self.index["books"].items()
            if not info.get("has_metadata")
        ]

    def get_books_needing_reviews(self) -> list[str]:
        """Return goodreads_ids of books that need review scraping."""
        return [
            gid
            for gid, info in self.index["books"].items()
            if info.get("has_metadata") and not info.get("has_reviews")
        ]

    def get_books_needing_analysis(self) -> list[str]:
        """Return goodreads_ids of books that have reviews but no analysis."""
        return [
            gid
            for gid, info in self.index["books"].items()
            if info.get("has_reviews") and not info.get("has_analysis")
        ]

    def get_books_with_recommendations(self) -> list[dict]:
        """Return all books that have recommendations."""
        return [
            self.get_book(gid)
            for gid, info in self.index["books"].items()
            if info.get("has_recommendation") and self.get_book(gid)
        ]

    # === SEARCH CACHING ===

    def get_cached_search(self, search_type: str, query_slug: str) -> Optional[dict]:
        """Get cached search results if available."""
        path = self.searches_dir / search_type / f"{query_slug}.json"
        if path.exists():
            return json.loads(path.read_text())
        return None

    def cache_search(self, search_type: str, query_slug: str, query: str, results: list) -> None:
        """Cache search results."""
        search_dir = self.searches_dir / search_type
        search_dir.mkdir(parents=True, exist_ok=True)

        data = {
            "query": query,
            "searched_at": _now_iso(),
            "results": results,
        }
        path = search_dir / f"{query_slug}.json"
        path.write_text(json.dumps(data, indent=2))

    def get_all_cached_searches(self, search_type: str) -> list[dict]:
        """Get all cached searches of a given type."""
        search_dir = self.searches_dir / search_type
        if not search_dir.exists():
            return []

        searches = []
        for path in search_dir.glob("*.json"):
            searches.append(json.loads(path.read_text()))
        return searches

    # === UPDATES ===

    def add_candidate(
        self,
        goodreads_id: str,
        title: str,
        author: str,
        sources: list[dict],
    ) -> None:
        """Add a new candidate to the library (minimal info)."""
        if goodreads_id in self.index["books"]:
            # Merge sources with existing
            book = self.get_book(goodreads_id)
            if book:
                existing_sources = book.get("recommendation", {}).get("sources", [])
                book.setdefault("recommendation", {})["sources"] = existing_sources + sources
                self._save_book(goodreads_id, book)
        else:
            book = {
                "goodreads_id": goodreads_id,
                "title": title,
                "author": author,
                "goodreads_url": f"https://www.goodreads.com/book/show/{goodreads_id}",
                "recommendation": {"sources": sources},
            }
            self._save_book(goodreads_id, book)
            self.index["books"][goodreads_id] = {
                "title": title,
                "author": author,
                "has_metadata": False,
                "has_reviews": False,
                "has_analysis": False,
                "has_recommendation": False,
                "tier": None,
            }
            self._save_index()

    def add_metadata(self, goodreads_id: str, metadata: dict) -> None:
        """Add metadata to an existing book record."""
        book = self.get_book(goodreads_id)
        if not book:
            return

        book["metadata"] = {**metadata, "fetched_at": _now_iso()}

        # Also update series info if present
        if "series" in metadata:
            book["series"] = metadata.pop("series")

        self._save_book(goodreads_id, book)
        self.index["books"][goodreads_id]["has_metadata"] = True
        self._save_index()

    def add_reviews(self, goodreads_id: str, reviews: dict) -> None:
        """Add scraped reviews to an existing book record."""
        book = self.get_book(goodreads_id)
        if not book:
            return

        book["reviews"] = {**reviews, "fetched_at": _now_iso()}
        self._save_book(goodreads_id, book)
        self.index["books"][goodreads_id]["has_reviews"] = True
        self._save_index()

    def add_analysis(self, goodreads_id: str, analysis: dict) -> None:
        """Add LLM analysis to an existing book record."""
        book = self.get_book(goodreads_id)
        if not book:
            return

        book["analysis"] = {**analysis, "generated_at": _now_iso()}
        self._save_book(goodreads_id, book)
        self.index["books"][goodreads_id]["has_analysis"] = True
        self._save_index()

    def set_recommendation(
        self,
        goodreads_id: str,
        tier: str,
        reasoning: str,
        dealbreakers: list[str],
    ) -> None:
        """Set final recommendation for a book."""
        book = self.get_book(goodreads_id)
        if not book:
            return

        book.setdefault("recommendation", {}).update(
            {
                "generated_at": _now_iso(),
                "tier": tier,
                "reasoning": reasoning,
                "dealbreakers": dealbreakers,
            }
        )
        self._save_book(goodreads_id, book)
        self.index["books"][goodreads_id]["has_recommendation"] = True
        self.index["books"][goodreads_id]["tier"] = tier
        self._save_index()

    # === STATUS ===

    def get_status(self) -> dict:
        """Get current pipeline status."""
        books = self.index["books"]
        return {
            "total_candidates": len(books),
            "with_metadata": sum(1 for b in books.values() if b.get("has_metadata")),
            "with_reviews": sum(1 for b in books.values() if b.get("has_reviews")),
            "with_analysis": sum(1 for b in books.values() if b.get("has_analysis")),
            "with_recommendation": sum(1 for b in books.values() if b.get("has_recommendation")),
            "needing_metadata": len(self.get_books_needing_metadata()),
            "needing_reviews": len(self.get_books_needing_reviews()),
            "needing_analysis": len(self.get_books_needing_analysis()),
        }

    # === INTERNAL ===

    def _save_book(self, goodreads_id: str, book: dict) -> None:
        """Save a book record to disk."""
        path = self.books_dir / f"{goodreads_id}.json"
        path.write_text(json.dumps(book, indent=2))

    def _save_index(self) -> None:
        """Save the index to disk."""
        self.index["last_updated"] = _now_iso()
        self.index_path.write_text(json.dumps(self.index, indent=2))

    def _load_index(self) -> dict:
        """Load the index from disk, or create a new one."""
        if self.index_path.exists():
            return json.loads(self.index_path.read_text())
        return {"version": 1, "books": {}, "last_updated": _now_iso()}

    def _load_already_read(self) -> set[str]:
        """Load the set of already-read book IDs from the CSV."""
        already_read = set()
        if READ_BOOKS_CSV.exists():
            with open(READ_BOOKS_CSV, encoding="utf-8") as f:
                reader = csv.DictReader(f)
                for row in reader:
                    if gid := row.get("goodreads_id"):
                        already_read.add(str(gid))
        return already_read


def _now_iso() -> str:
    """Return current UTC time in ISO format."""
    return datetime.now(timezone.utc).isoformat()
