"""Scrape genre information from Goodreads."""

import asyncio
import csv
import random
from pathlib import Path

import aiohttp
from bs4 import BeautifulSoup
from tqdm.asyncio import tqdm

GOODREADS_URL = "https://www.goodreads.com/book/show/{book_id}"
USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"


async def fetch_genres(
    session: aiohttp.ClientSession,
    book_id: str,
    max_retries: int = 3,
) -> list[str]:
    """
    Fetch genres for a single book from Goodreads.

    Uses exponential backoff with jitter on failure.
    Returns empty list if all retries fail.
    """
    url = GOODREADS_URL.format(book_id=book_id)

    for attempt in range(max_retries):
        try:
            async with session.get(url) as response:
                if response.status == 200:
                    html = await response.text()
                    return parse_genres(html)
                elif response.status == 429:
                    # Rate limited - wait longer
                    wait = (2 ** attempt) + random.uniform(1, 3)
                    await asyncio.sleep(wait)
                else:
                    # Other error - brief backoff
                    await asyncio.sleep(0.5 * (attempt + 1))
        except (aiohttp.ClientError, asyncio.TimeoutError):
            wait = (2 ** attempt) * 0.5 + random.uniform(0, 0.5)
            await asyncio.sleep(wait)

    return []  # All retries failed


def parse_genres(html: str) -> list[str]:
    """Extract genre list from Goodreads book page HTML."""
    soup = BeautifulSoup(html, "lxml")

    genres = []
    # Goodreads uses data-testid for genre buttons
    genre_elements = soup.select('[data-testid="genresList"] a[href*="/genres/"]')

    for el in genre_elements:
        genre = el.get_text(strip=True)
        if genre and genre not in genres:
            genres.append(genre)

    # Fallback: try older page structure
    if not genres:
        for link in soup.select('a[href*="/genres/"]'):
            genre = link.get_text(strip=True)
            if genre and genre not in genres and len(genre) < 50:
                genres.append(genre)

    return genres


async def process_book(
    session: aiohttp.ClientSession,
    semaphore: asyncio.Semaphore,
    book: dict,
    max_retries: int,
    pbar: tqdm,
) -> dict:
    """Process a single book: fetch genres and update the record."""
    async with semaphore:
        genres = await fetch_genres(session, book["goodreads_id"], max_retries)
        book["genres"] = "|".join(genres)
        pbar.update(1)
        return book


async def add_genres_async(
    input_path: Path,
    output_path: Path,
    concurrency: int = 5,
    max_retries: int = 3,
) -> tuple[int, int]:
    """
    Add genres to a clean Goodreads export.

    Returns (total_books, books_with_genres).
    """
    # Read input
    with open(input_path, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        books = list(reader)

    if not books:
        return 0, 0

    # Setup async scraping
    semaphore = asyncio.Semaphore(concurrency)
    timeout = aiohttp.ClientTimeout(total=30)
    headers = {"User-Agent": USER_AGENT}

    connector = aiohttp.TCPConnector(limit=concurrency, limit_per_host=concurrency)

    with tqdm(total=len(books), desc="Fetching genres", unit="book") as pbar:
        async with aiohttp.ClientSession(
            timeout=timeout,
            headers=headers,
            connector=connector,
        ) as session:
            # Use TaskGroup for structured concurrency (Python 3.11+)
            async with asyncio.TaskGroup() as tg:
                tasks = [
                    tg.create_task(
                        process_book(session, semaphore, book, max_retries, pbar)
                    )
                    for book in books
                ]

            results = [task.result() for task in tasks]

    # Write output
    fieldnames = list(books[0].keys())
    if "genres" not in fieldnames:
        fieldnames.append("genres")

    with open(output_path, "w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(results)

    books_with_genres = sum(1 for b in results if b.get("genres"))
    return len(results), books_with_genres


def add_genres(
    input_path: str | Path,
    output_path: str | Path,
    concurrency: int = 5,
    max_retries: int = 3,
) -> tuple[int, int]:
    """
    Synchronous wrapper for add_genres_async.

    Returns (total_books, books_with_genres).
    """
    return asyncio.run(
        add_genres_async(
            Path(input_path),
            Path(output_path),
            concurrency,
            max_retries,
        )
    )
