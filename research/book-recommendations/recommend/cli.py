"""Command-line interface for the recommendation system."""

import argparse
import sys
from pathlib import Path

from .config import LIBRARY_DIR, TOP_CANDIDATES_FOR_REVIEW, REVIEWS_PER_STAR_RATING
from .library import BookLibrary
from .candidates import load_already_read, normalize_title, normalize_author
from .report import generate_report, generate_status_report
from .scrape import get_book_one, scrape_candidates as scrape_metadata_batch
from .scrape_playwright import scrape_reviews_batch


def cmd_status(args: argparse.Namespace) -> int:
    """Show current pipeline status."""
    library = BookLibrary(Path(args.library))
    print(generate_status_report(library))
    return 0


def cmd_scrape_candidates(args: argparse.Namespace) -> int:
    """Scrape metadata and reviews for top candidates."""
    library = BookLibrary(Path(args.library))

    # Get candidates needing scraping
    need_meta = library.get_books_needing_metadata()
    need_reviews = library.get_books_needing_reviews()

    if args.metadata_only:
        ids = need_meta[: args.top]
        if not ids:
            print("No candidates need metadata.")
            return 0

        print(f"Scraping metadata for {len(ids)} candidates...")
        count = scrape_metadata_batch(library, ids, fetch_reviews=False)
        print(f"Successfully scraped metadata for {count} books.")
        return 0

    # Full scrape: metadata first (fast, async), then reviews (Playwright)
    all_ids = list(set(need_meta) | set(need_reviews))[: args.top]

    if not all_ids:
        print("No candidates need scraping.")
        return 0

    # Step 1: Metadata via aiohttp (fast)
    meta_ids = [gid for gid in all_ids if gid in need_meta]
    if meta_ids:
        print(f"Scraping metadata for {len(meta_ids)} candidates...")
        scrape_metadata_batch(library, meta_ids, fetch_reviews=False)

    # Step 2: Reviews via Playwright (balanced 1★, 3★, 5★)
    review_ids = [gid for gid in all_ids if not library.has_reviews(gid)]
    if review_ids:
        print(f"Scraping reviews for {len(review_ids)} candidates (3 each from 1★, 3★, 5★)...")
        results = scrape_reviews_batch(
            review_ids,
            target_stars=[5, 3, 1],
            reviews_per_rating=REVIEWS_PER_STAR_RATING,
        )
        for gid, reviews in results.items():
            library.add_reviews(gid, reviews)
        print(f"Successfully scraped reviews for {len(results)} books.")

    print(f"Done. Scraped {len(all_ids)} candidates.")
    return 0


def cmd_generate_report(args: argparse.Namespace) -> int:
    """Generate recommendations report."""
    library = BookLibrary(Path(args.library))

    books = library.get_books_with_recommendations()
    if not books:
        print("No books with recommendations found.")
        print("Run analysis first to generate recommendations.")
        return 1

    output_path = generate_report(library)
    print(f"Report generated: {output_path}")
    return 0


def cmd_list_candidates(args: argparse.Namespace) -> int:
    """List all candidates in the library."""
    library = BookLibrary(Path(args.library))

    books = library.get_all_books()
    if not books:
        print("No candidates in library.")
        return 0

    # Sort by title
    books.sort(key=lambda b: b.get("title", "").lower())

    print(f"{'Title':<40} {'Author':<25} {'Status':<15}")
    print("-" * 80)

    for book in books:
        title = book.get("title", "Unknown")[:38]
        author = book.get("author", "Unknown")[:23]

        # Determine status
        gid = book.get("goodreads_id", "")
        if library.has_reviews(gid):
            status = "has reviews"
        elif library.has_metadata(gid):
            status = "has metadata"
        else:
            status = "pending"

        print(f"{title:<40} {author:<25} {status:<15}")

    print(f"\nTotal: {len(books)} candidates")
    return 0


def cmd_list_ready(args: argparse.Namespace) -> int:
    """List candidates ready for analysis (have reviews, no recommendation yet)."""
    library = BookLibrary(Path(args.library))

    ids = library.get_books_needing_analysis()
    if not ids:
        print("No candidates ready for analysis.", file=sys.stderr)
        return 0

    if args.ids_only:
        for gid in ids:
            print(gid)
    else:
        for gid in ids:
            book = library.get_book(gid)
            if book:
                print(f"{gid}\t{book.get('title', 'Unknown')}\t{book.get('author', 'Unknown')}")

    return 0


def cmd_check_read(args: argparse.Namespace) -> int:
    """Check if a book has already been read."""
    read_books = load_already_read()
    query = normalize_title(args.title) + "|" + normalize_author(args.author)

    # Exact match
    if query in read_books:
        print("YES - already read")
        return 1

    # Fuzzy check
    from .candidates import are_duplicates
    for read_key in read_books:
        read_title, read_author = read_key.split("|", 1)
        if are_duplicates(args.title, args.author, read_title, read_author, threshold=90):
            print(f"YES - already read (matched: {read_title})")
            return 1

    print("NO - not in read list")
    return 0


def cmd_check_series(args: argparse.Namespace) -> int:
    """Check if a book is part of a series and find Book 1."""
    print(f"Checking {args.id}...", file=sys.stderr)

    result = get_book_one(args.id)

    if result is None:
        print("Not part of a series, or already Book 1.")
        return 0

    print(f"Book 1: {result.get('title')} by {result.get('author')}")
    print(f"ID: {result.get('goodreads_id')}")

    if args.add:
        library = BookLibrary(Path(args.library))
        library.add_candidate(
            goodreads_id=result["goodreads_id"],
            title=result["title"],
            author=result["author"] or "Unknown",
            sources=[{"type": "series_resolution", "original_id": args.id}],
        )
        print(f"Added to library.")

    return 0


def cmd_add_candidate(args: argparse.Namespace) -> int:
    """Manually add a candidate to the library."""
    library = BookLibrary(Path(args.library))

    library.add_candidate(
        goodreads_id=args.id,
        title=args.title,
        author=args.author,
        sources=[{"type": "manual", "note": args.note or "Added manually"}],
    )

    print(f"Added: {args.title} by {args.author} (ID: {args.id})")
    return 0


def main() -> int:
    """Main entry point."""
    parser = argparse.ArgumentParser(
        prog="recommend",
        description="Book recommendation system",
    )
    parser.add_argument(
        "--library",
        type=str,
        default=str(LIBRARY_DIR),
        help="Path to library directory",
    )

    subparsers = parser.add_subparsers(dest="command", required=True)

    # status command
    status_parser = subparsers.add_parser(
        "status",
        help="Show pipeline status",
    )
    status_parser.set_defaults(func=cmd_status)

    # scrape-candidates command
    scrape_parser = subparsers.add_parser(
        "scrape-candidates",
        help="Scrape metadata and reviews for candidates",
    )
    scrape_parser.add_argument(
        "--top",
        type=int,
        default=TOP_CANDIDATES_FOR_REVIEW,
        help=f"Maximum candidates to scrape (default: {TOP_CANDIDATES_FOR_REVIEW})",
    )
    scrape_parser.add_argument(
        "--metadata-only",
        action="store_true",
        help="Only fetch metadata, not reviews (faster)",
    )
    scrape_parser.set_defaults(func=cmd_scrape_candidates)

    # generate-report command
    report_parser = subparsers.add_parser(
        "generate-report",
        help="Generate recommendations markdown report",
    )
    report_parser.set_defaults(func=cmd_generate_report)

    # list command
    list_parser = subparsers.add_parser(
        "list",
        help="List all candidates in the library",
    )
    list_parser.set_defaults(func=cmd_list_candidates)

    # list-ready command
    ready_parser = subparsers.add_parser(
        "list-ready",
        help="List candidates ready for analysis (have reviews, need recommendation)",
    )
    ready_parser.add_argument(
        "--ids-only",
        action="store_true",
        help="Output only Goodreads IDs, one per line",
    )
    ready_parser.set_defaults(func=cmd_list_ready)

    # add command
    add_parser = subparsers.add_parser(
        "add",
        help="Manually add a candidate",
    )
    add_parser.add_argument("id", help="Goodreads book ID")
    add_parser.add_argument("title", help="Book title")
    add_parser.add_argument("author", help="Author name")
    add_parser.add_argument("--note", help="Optional note about source")
    add_parser.set_defaults(func=cmd_add_candidate)

    # check-series command
    series_parser = subparsers.add_parser(
        "check-series",
        help="Check if a book is Book 2+ and find Book 1",
    )
    series_parser.add_argument("id", help="Goodreads book ID to check")
    series_parser.add_argument(
        "--add",
        action="store_true",
        help="Automatically add Book 1 to library if found",
    )
    series_parser.set_defaults(func=cmd_check_series)

    # check-read command
    read_parser = subparsers.add_parser(
        "check-read",
        help="Check if a book has already been read",
    )
    read_parser.add_argument("title", help="Book title")
    read_parser.add_argument("author", help="Author name")
    read_parser.set_defaults(func=cmd_check_read)

    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
