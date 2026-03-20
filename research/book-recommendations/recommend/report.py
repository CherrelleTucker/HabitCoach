"""Generate recommendation reports."""

from datetime import datetime, timezone
from pathlib import Path

from .config import OUTPUT_DIR
from .library import BookLibrary


def generate_report(
    library: BookLibrary,
    output_path: Path = OUTPUT_DIR / "recommendations.md",
) -> Path:
    """
    Generate a markdown recommendations report from analyzed books.

    Groups books by recommendation tier and includes reasoning.

    Returns the path to the generated report.
    """
    output_path.parent.mkdir(parents=True, exist_ok=True)

    books = library.get_books_with_recommendations()

    # Group by tier
    tiers = {
        "high": [],
        "medium": [],
        "try": [],
        "skip": [],
    }

    for book in books:
        rec = book.get("recommendation", {})
        tier = rec.get("tier", "skip")
        if tier in tiers:
            tiers[tier].append(book)

    # Sort each tier by frequency score
    for tier in tiers:
        tiers[tier].sort(
            key=lambda b: b.get("recommendation", {}).get("frequency_score", 0),
            reverse=True,
        )

    # Generate report
    lines = [
        "# Book Recommendations",
        "",
        f"Generated: {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M UTC')}",
        f"Total candidates analyzed: {len(books)}",
        "",
        "---",
        "",
    ]

    # High confidence
    if tiers["high"]:
        lines.extend(_format_tier("High Confidence", tiers["high"]))

    # Medium confidence
    if tiers["medium"]:
        lines.extend(_format_tier("Medium Confidence", tiers["medium"]))

    # Worth a try
    if tiers["try"]:
        lines.extend(_format_tier("Worth a Try", tiers["try"]))

    # Skipped
    if tiers["skip"]:
        lines.append("## Skipped")
        lines.append("")
        lines.append("| Title | Author | Reason |")
        lines.append("|-------|--------|--------|")
        for book in tiers["skip"]:
            title = book.get("title", "Unknown")
            author = book.get("author", "Unknown")
            rec = book.get("recommendation", {})
            reason = rec.get("reasoning", "No reason given")
            # Truncate reason for table
            if len(reason) > 60:
                reason = reason[:57] + "..."
            lines.append(f"| {title} | {author} | {reason} |")
        lines.append("")

    output_path.write_text("\n".join(lines))
    return output_path


def _format_tier(tier_name: str, books: list[dict]) -> list[str]:
    """Format a tier section for the report."""
    lines = [
        f"## {tier_name}",
        "",
    ]

    for i, book in enumerate(books, 1):
        title = book.get("title", "Unknown")
        author = book.get("author", "Unknown")
        rec = book.get("recommendation", {})
        meta = book.get("metadata", {})
        analysis = book.get("analysis", {})

        lines.append(f"### {i}. {title} by {author}")
        lines.append("")

        # Why
        reasoning = rec.get("reasoning", "")
        if reasoning:
            lines.append(f"**Why**: {reasoning}")
            lines.append("")

        # Source
        sources = rec.get("sources", [])
        if sources:
            source_strs = []
            for s in sources[:3]:  # Limit to 3 sources
                if s.get("type") == "similar":
                    source_strs.append(f"Similar to {s.get('seed', 'unknown')}")
                elif s.get("type") == "author":
                    source_strs.append(f"By author search")
                elif s.get("type") == "style":
                    source_strs.append(f"Style: {s.get('query', 'unknown')}")
            if source_strs:
                lines.append(f"**Source**: {' | '.join(source_strs)}")
                lines.append("")

        # Genre
        genres = meta.get("genres", [])
        if genres:
            lines.append(f"**Genre**: {', '.join(genres[:5])}")
            lines.append("")

        # Potential concerns / dealbreakers
        dealbreakers = rec.get("dealbreakers", [])
        if dealbreakers:
            lines.append(f"**Potential concerns**: {', '.join(dealbreakers)}")
            lines.append("")

        # Themes from analysis
        themes = analysis.get("themes", {})
        praised = themes.get("praised_for", [])
        criticized = themes.get("criticized_for", [])

        if praised:
            lines.append(f"**Praised for**: {', '.join(praised[:3])}")
        if criticized:
            lines.append(f"**Criticized for**: {', '.join(criticized[:3])}")

        lines.append("")

    lines.append("---")
    lines.append("")

    return lines


def generate_status_report(library: BookLibrary) -> str:
    """Generate a text status report for the pipeline."""
    status = library.get_status()

    lines = [
        "Pipeline Status",
        "=" * 40,
        "",
        f"Total candidates:        {status['total_candidates']:>5}",
        f"With metadata:           {status['with_metadata']:>5}",
        f"With reviews:            {status['with_reviews']:>5}",
        f"With analysis:           {status['with_analysis']:>5}",
        f"With recommendation:     {status['with_recommendation']:>5}",
        "",
        "Pending Work",
        "-" * 40,
        f"Needing metadata:        {status['needing_metadata']:>5}",
        f"Needing reviews:         {status['needing_reviews']:>5}",
        f"Needing analysis:        {status['needing_analysis']:>5}",
    ]

    return "\n".join(lines)
