"""Command-line interface for Goodreads tools."""

import argparse
import sys
from pathlib import Path

from .analyze import analyze_genres
from .clean import clean_export
from .scrape import add_genres


def cmd_clean(args: argparse.Namespace) -> int:
    """Handle the 'clean' subcommand."""
    input_path = Path(args.input)
    output_path = Path(args.output)

    if not input_path.exists():
        print(f"Error: Input file not found: {input_path}", file=sys.stderr)
        return 1

    count = clean_export(input_path, output_path)
    print(f"Wrote {count} read books to {output_path}")
    return 0


def cmd_genres(args: argparse.Namespace) -> int:
    """Handle the 'genres' subcommand."""
    input_path = Path(args.input)
    output_path = Path(args.output)

    if not input_path.exists():
        print(f"Error: Input file not found: {input_path}", file=sys.stderr)
        return 1

    try:
        total, with_genres = add_genres(
            input_path,
            output_path,
            concurrency=args.concurrency,
            max_retries=args.retry,
        )
        print(f"Processed {total} books, {with_genres} with genres found")
        print(f"Output written to {output_path}")
        return 0
    except KeyboardInterrupt:
        print("\nInterrupted - partial results may have been written")
        return 130


def cmd_analyze(args: argparse.Namespace) -> int:
    """Handle the 'analyze' subcommand."""
    input_path = Path(args.input)
    output_dir = Path(args.output_dir)

    if not input_path.exists():
        print(f"Error: Input file not found: {input_path}", file=sys.stderr)
        return 1

    stats = analyze_genres(input_path, output_dir)
    print(f"Analyzed {stats['total_books']} books across {stats['unique_genres']} genres")
    print(f"Fiction: {stats['fiction_counts'].get('Fiction', 0)}, Non-Fiction: {stats['fiction_counts'].get('Non-Fiction', 0)}")
    print(f"Output written to {output_dir}/")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(
        prog="goodreads",
        description="Utilities for processing Goodreads library exports",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    # clean subcommand
    clean_parser = subparsers.add_parser(
        "clean",
        help="Convert raw Goodreads export to clean format",
    )
    clean_parser.add_argument("input", help="Raw Goodreads CSV export")
    clean_parser.add_argument("output", help="Output CSV path")
    clean_parser.set_defaults(func=cmd_clean)

    # genres subcommand
    genres_parser = subparsers.add_parser(
        "genres",
        help="Scrape and add genre information",
    )
    genres_parser.add_argument("input", help="Clean CSV (from 'clean' command)")
    genres_parser.add_argument("output", help="Output CSV with genres")
    genres_parser.add_argument(
        "--concurrency",
        type=int,
        default=5,
        help="Number of parallel requests (default: 5)",
    )
    genres_parser.add_argument(
        "--retry",
        type=int,
        default=3,
        help="Max retry attempts per book (default: 3)",
    )
    genres_parser.set_defaults(func=cmd_genres)

    # analyze subcommand
    analyze_parser = subparsers.add_parser(
        "analyze",
        help="Analyze genre data and generate visualizations",
    )
    analyze_parser.add_argument("input", help="CSV with genres column")
    analyze_parser.add_argument("output_dir", help="Output directory for graphs and stats")
    analyze_parser.set_defaults(func=cmd_analyze)

    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
