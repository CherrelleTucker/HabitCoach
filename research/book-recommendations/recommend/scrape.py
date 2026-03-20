"""Scrape book metadata and reviews from Goodreads."""

import asyncio
import random
import re
from typing import Optional

import aiohttp
from bs4 import BeautifulSoup
from tqdm.asyncio import tqdm

from .config import (
    GOODREADS_BASE_URL,
    MAX_CONCURRENT_REQUESTS,
    MAX_RETRIES,
    REVIEWS_PER_STAR_RATING,
    SCRAPE_DELAY_SECONDS,
    USER_AGENT,
)
from .library import BookLibrary


async def fetch_page(
    session: aiohttp.ClientSession,
    url: str,
    max_retries: int = MAX_RETRIES,
) -> Optional[str]:
    """
    Fetch a page with exponential backoff on failure.

    Returns None if all retries fail.
    """
    for attempt in range(max_retries):
        try:
            async with session.get(url) as response:
                if response.status == 200:
                    return await response.text()
                elif response.status == 429:
                    # Rate limited
                    wait = (2**attempt) + random.uniform(1, 3)
                    await asyncio.sleep(wait)
                else:
                    await asyncio.sleep(0.5 * (attempt + 1))
        except (aiohttp.ClientError, asyncio.TimeoutError):
            wait = (2**attempt) * 0.5 + random.uniform(0, 0.5)
            await asyncio.sleep(wait)

    return None


def parse_book_metadata(html: str) -> dict:
    """Extract metadata from a Goodreads book page."""
    soup = BeautifulSoup(html, "lxml")
    metadata = {}

    # Title
    title_el = soup.select_one('h1[data-testid="bookTitle"]')
    if title_el:
        metadata["title"] = title_el.get_text(strip=True)

    # Author
    author_el = soup.select_one('span[data-testid="name"]')
    if author_el:
        metadata["author"] = author_el.get_text(strip=True)

    # Genres
    genres = []
    genre_elements = soup.select('[data-testid="genresList"] a[href*="/genres/"]')
    for el in genre_elements:
        genre = el.get_text(strip=True)
        if genre and genre not in genres:
            genres.append(genre)
    metadata["genres"] = genres

    # Average rating
    rating_el = soup.select_one('div[class*="RatingStatistics__rating"]')
    if rating_el:
        try:
            metadata["avg_rating"] = float(rating_el.get_text(strip=True))
        except ValueError:
            pass

    # Number of ratings
    ratings_count_el = soup.select_one('span[data-testid="ratingsCount"]')
    if ratings_count_el:
        text = ratings_count_el.get_text(strip=True)
        # Parse "1,234,567 ratings"
        num = re.sub(r"[^\d]", "", text)
        if num:
            metadata["num_ratings"] = int(num)

    # Number of pages
    pages_el = soup.select_one('p[data-testid="pagesFormat"]')
    if pages_el:
        text = pages_el.get_text(strip=True)
        match = re.search(r"(\d+)\s*pages?", text, re.IGNORECASE)
        if match:
            metadata["num_pages"] = int(match.group(1))

    # Publication year
    pub_el = soup.select_one('p[data-testid="publicationInfo"]')
    if pub_el:
        text = pub_el.get_text(strip=True)
        match = re.search(r"(\d{4})", text)
        if match:
            metadata["publication_year"] = int(match.group(1))

    # Description
    desc_el = soup.select_one('div[data-testid="description"]')
    if desc_el:
        # Get the truncated or full description
        spans = desc_el.select("span")
        if spans:
            metadata["description"] = spans[-1].get_text(strip=True)

    # Series info
    series_el = soup.select_one('h3[class*="Text__title3"] a[href*="/series/"]')
    if series_el:
        series_text = series_el.get_text(strip=True)
        series_url = series_el.get("href", "")

        # Parse "Series Name #1"
        match = re.match(r"(.+?)\s*#(\d+)", series_text)
        if match:
            metadata["series"] = {
                "name": match.group(1).strip(),
                "position": int(match.group(2)),
                "series_url": series_url,
            }

    return metadata


def parse_reviews(html: str, target_stars: list[int]) -> dict:
    """
    Extract reviews from a Goodreads book page.

    Note: Goodreads loads reviews dynamically, so this may only get
    the initially visible reviews. For more comprehensive scraping,
    we'd need to use their API or handle JavaScript.
    """
    soup = BeautifulSoup(html, "lxml")
    reviews = {f"{s}_star": [] for s in target_stars}

    # Find review containers
    review_cards = soup.select('article[class*="ReviewCard"]')

    for card in review_cards:
        # Get star rating
        stars_el = card.select_one('span[class*="RatingStars"]')
        if not stars_el:
            continue

        # Count filled stars (aria-label like "Rating 4 out of 5")
        aria = stars_el.get("aria-label", "")
        match = re.search(r"Rating\s+(\d+)", aria)
        if not match:
            continue

        stars = int(match.group(1))
        star_key = f"{stars}_star"

        if star_key not in reviews:
            continue

        if len(reviews[star_key]) >= REVIEWS_PER_STAR_RATING:
            continue

        # Get review text
        text_el = card.select_one('section[class*="ReviewText"]')
        if not text_el:
            continue

        # Get the full text from spans
        spans = text_el.select("span")
        review_text = spans[-1].get_text(strip=True) if spans else ""

        if not review_text or len(review_text) < 50:
            continue

        # Get likes count
        likes = 0
        likes_el = card.select_one('span[class*="SocialFooter__count"]')
        if likes_el:
            try:
                likes = int(re.sub(r"[^\d]", "", likes_el.get_text()))
            except ValueError:
                pass

        reviews[star_key].append(
            {
                "text": review_text[:5000],  # Limit length
                "likes": likes,
            }
        )

    return reviews


def parse_series_page(html: str) -> Optional[dict]:
    """
    Extract Book 1 info from a Goodreads series page.

    Returns dict with goodreads_id, title, author for Book 1, or None if not found.
    """
    soup = BeautifulSoup(html, "lxml")

    # Find the first book in the series (usually marked as #1)
    # Series pages list books with their position
    book_items = soup.select('div[itemtype="http://schema.org/Book"]')

    for item in book_items:
        # Check if this is Book 1
        position_el = item.select_one('span[class*="bookMeta"]')
        if position_el:
            text = position_el.get_text()
            if re.search(r'#1\b|Book 1\b', text):
                # Found Book 1
                title_el = item.select_one('a[class*="bookTitle"]')
                author_el = item.select_one('a[class*="authorName"]')

                if title_el:
                    href = title_el.get("href", "")
                    # Extract ID from URL like /book/show/12345
                    id_match = re.search(r'/book/show/(\d+)', href)

                    return {
                        "goodreads_id": id_match.group(1) if id_match else None,
                        "title": title_el.get_text(strip=True),
                        "author": author_el.get_text(strip=True) if author_el else None,
                    }

    # Fallback: try alternate page structure
    first_book = soup.select_one('tr[itemtype="http://schema.org/Book"]')
    if first_book:
        title_el = first_book.select_one('a.bookTitle')
        author_el = first_book.select_one('a.authorName')
        if title_el:
            href = title_el.get("href", "")
            id_match = re.search(r'/book/show/(\d+)', href)
            return {
                "goodreads_id": id_match.group(1) if id_match else None,
                "title": title_el.get_text(strip=True),
                "author": author_el.get_text(strip=True) if author_el else None,
            }

    return None


async def scrape_series_book_one(
    session: aiohttp.ClientSession,
    series_url: str,
) -> Optional[dict]:
    """Fetch series page and return Book 1 info."""
    html = await fetch_page(session, series_url)
    if not html:
        return None
    return parse_series_page(html)


async def get_book_one_async(goodreads_id: str) -> Optional[dict]:
    """
    Given a book ID, check if it's part of a series and return Book 1 info.

    Returns:
        - None if book is not part of a series
        - None if book is already Book 1
        - Dict with Book 1's goodreads_id, title, author if found
    """
    timeout = aiohttp.ClientTimeout(total=30)
    headers = {"User-Agent": USER_AGENT}

    async with aiohttp.ClientSession(timeout=timeout, headers=headers) as session:
        # First get the book's metadata to find series info
        metadata = await scrape_book_metadata(session, goodreads_id)
        if not metadata:
            return None

        series = metadata.get("series")
        if not series:
            return None  # Not part of a series

        if series.get("position") == 1:
            return None  # Already Book 1

        series_url = series.get("series_url")
        if not series_url:
            return None

        # Make sure URL is absolute
        if not series_url.startswith("http"):
            series_url = f"{GOODREADS_BASE_URL}{series_url}"

        return await scrape_series_book_one(session, series_url)


def get_book_one(goodreads_id: str) -> Optional[dict]:
    """Synchronous wrapper for get_book_one_async."""
    return asyncio.run(get_book_one_async(goodreads_id))


async def scrape_book_metadata(
    session: aiohttp.ClientSession,
    goodreads_id: str,
) -> Optional[dict]:
    """Fetch and parse metadata for a single book."""
    url = f"{GOODREADS_BASE_URL}/book/show/{goodreads_id}"
    html = await fetch_page(session, url)
    if not html:
        return None
    return parse_book_metadata(html)


async def scrape_book_reviews(
    session: aiohttp.ClientSession,
    goodreads_id: str,
    target_stars: list[int] = [5, 3, 1],
) -> Optional[dict]:
    """Fetch and parse reviews for a single book."""
    url = f"{GOODREADS_BASE_URL}/book/show/{goodreads_id}"
    html = await fetch_page(session, url)
    if not html:
        return None
    return parse_reviews(html, target_stars)


async def scrape_candidate(
    session: aiohttp.ClientSession,
    semaphore: asyncio.Semaphore,
    library: BookLibrary,
    goodreads_id: str,
    pbar: tqdm,
    fetch_reviews: bool = True,
) -> bool:
    """
    Scrape metadata and optionally reviews for a candidate.

    Returns True if successful.
    """
    async with semaphore:
        # Fetch metadata if needed
        if not library.has_metadata(goodreads_id):
            metadata = await scrape_book_metadata(session, goodreads_id)
            if metadata:
                library.add_metadata(goodreads_id, metadata)
            await asyncio.sleep(SCRAPE_DELAY_SECONDS)

        # Fetch reviews if needed and requested
        if fetch_reviews and not library.has_reviews(goodreads_id):
            reviews = await scrape_book_reviews(session, goodreads_id)
            if reviews:
                library.add_reviews(goodreads_id, reviews)
            await asyncio.sleep(SCRAPE_DELAY_SECONDS)

        pbar.update(1)
        return True


async def scrape_candidates_async(
    library: BookLibrary,
    goodreads_ids: list[str],
    fetch_reviews: bool = True,
    concurrency: int = MAX_CONCURRENT_REQUESTS,
) -> int:
    """
    Scrape metadata and reviews for multiple candidates.

    Returns count of successfully scraped books.
    """
    if not goodreads_ids:
        return 0

    semaphore = asyncio.Semaphore(concurrency)
    timeout = aiohttp.ClientTimeout(total=30)
    headers = {"User-Agent": USER_AGENT}
    connector = aiohttp.TCPConnector(limit=concurrency, limit_per_host=concurrency)

    success_count = 0

    with tqdm(total=len(goodreads_ids), desc="Scraping books", unit="book") as pbar:
        async with aiohttp.ClientSession(
            timeout=timeout,
            headers=headers,
            connector=connector,
        ) as session:
            tasks = [
                scrape_candidate(
                    session, semaphore, library, gid, pbar, fetch_reviews
                )
                for gid in goodreads_ids
            ]

            results = await asyncio.gather(*tasks, return_exceptions=True)
            success_count = sum(1 for r in results if r is True)

    return success_count


def scrape_candidates(
    library: BookLibrary,
    goodreads_ids: list[str],
    fetch_reviews: bool = True,
    concurrency: int = MAX_CONCURRENT_REQUESTS,
) -> int:
    """
    Synchronous wrapper for scrape_candidates_async.

    Returns count of successfully scraped books.
    """
    return asyncio.run(
        scrape_candidates_async(library, goodreads_ids, fetch_reviews, concurrency)
    )
