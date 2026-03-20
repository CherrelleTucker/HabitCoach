"""Analyze genre data from Goodreads exports."""

import csv
from collections import Counter
from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd

# Genres that indicate non-fiction
NONFICTION_GENRES = {
    "nonfiction",
    "history",
    "biography",
    "science",
    "economics",
    "politics",
    "philosophy",
    "psychology",
    "sociology",
    "anthropology",
    "business",
    "finance",
    "religion",
    "self-help",
    "memoir",
    "autobiography",
    "essays",
    "journalism",
    "travel",
    "cooking",
    "art",
    "music",
    "sports",
    "nature",
    "health",
    "education",
    "reference",
    "true crime",
    "world history",
    "military history",
}


def load_books(input_path: Path) -> pd.DataFrame:
    """Load books CSV and parse genres into lists."""
    df = pd.read_csv(input_path)
    df["genre_list"] = df["genres"].fillna("").apply(
        lambda x: [g.strip() for g in x.split("|") if g.strip()]
    )
    return df


def classify_fiction(genres: list[str]) -> str:
    """Classify a book as Fiction or Non-Fiction based on genres."""
    genres_lower = {g.lower() for g in genres}

    # Check for explicit non-fiction markers
    if genres_lower & NONFICTION_GENRES:
        return "Non-Fiction"

    # Default to fiction if has any genres, unknown if none
    return "Fiction" if genres else "Unknown"


def count_genres(df: pd.DataFrame) -> Counter:
    """Count occurrences of each genre across all books."""
    genre_counts = Counter()
    for genres in df["genre_list"]:
        genre_counts.update(genres)
    return genre_counts


def rating_by_genre(df: pd.DataFrame) -> dict[str, dict]:
    """Calculate average rating per genre."""
    genre_ratings: dict[str, list[int]] = {}

    for _, row in df.iterrows():
        rating = row["my_rating"]
        if rating == 0:  # Skip unrated books
            continue
        for genre in row["genre_list"]:
            if genre not in genre_ratings:
                genre_ratings[genre] = []
            genre_ratings[genre].append(rating)

    return {
        genre: {
            "avg": sum(ratings) / len(ratings),
            "count": len(ratings),
        }
        for genre, ratings in genre_ratings.items()
    }


def plot_genre_histogram(genre_counts: Counter, output_path: Path, top_n: int = 20):
    """Create bar chart of most common genres."""
    top_genres = genre_counts.most_common(top_n)
    genres, counts = zip(*top_genres) if top_genres else ([], [])

    fig, ax = plt.subplots(figsize=(12, 8))
    bars = ax.barh(range(len(genres)), counts, color="#4a90d9")
    ax.set_yticks(range(len(genres)))
    ax.set_yticklabels(genres)
    ax.invert_yaxis()
    ax.set_xlabel("Number of Books")
    ax.set_title(f"Top {top_n} Genres by Book Count")

    # Add count labels on bars
    for bar, count in zip(bars, counts):
        ax.text(bar.get_width() + 0.5, bar.get_y() + bar.get_height() / 2,
                str(count), va="center", fontsize=9)

    plt.tight_layout()
    plt.savefig(output_path, dpi=150)
    plt.close()


def plot_fiction_breakdown(df: pd.DataFrame, output_path: Path):
    """Create pie chart of fiction vs non-fiction."""
    df["fiction_class"] = df["genre_list"].apply(classify_fiction)
    counts = df["fiction_class"].value_counts()

    # Filter out Unknown if present
    counts = counts[counts.index != "Unknown"]

    fig, ax = plt.subplots(figsize=(8, 8))
    colors = ["#4a90d9", "#e74c3c"]
    wedges, texts, autotexts = ax.pie(
        counts.values,
        labels=counts.index,
        autopct=lambda p: f"{p:.1f}%\n({int(p * sum(counts.values) / 100)})",
        colors=colors[:len(counts)],
        startangle=90,
        textprops={"fontsize": 12},
    )
    ax.set_title("Fiction vs Non-Fiction")

    plt.tight_layout()
    plt.savefig(output_path, dpi=150)
    plt.close()

    return counts.to_dict()


def plot_rating_by_genre(genre_stats: dict, output_path: Path, min_books: int = 3, top_n: int = 20):
    """Create bar chart of average rating per genre."""
    # Filter to genres with minimum book count
    filtered = {
        g: s for g, s in genre_stats.items()
        if s["count"] >= min_books
    }

    # Sort by average rating
    sorted_genres = sorted(filtered.items(), key=lambda x: x[1]["avg"], reverse=True)[:top_n]

    if not sorted_genres:
        return

    genres, stats = zip(*sorted_genres)
    avgs = [s["avg"] for s in stats]
    counts = [s["count"] for s in stats]

    fig, ax = plt.subplots(figsize=(12, 8))
    bars = ax.barh(range(len(genres)), avgs, color="#27ae60")
    ax.set_yticks(range(len(genres)))
    ax.set_yticklabels(genres)
    ax.invert_yaxis()
    ax.set_xlabel("Average Rating")
    ax.set_xlim(0, 5)
    ax.set_title(f"Average Rating by Genre (min {min_books} books)")

    # Add rating and count labels
    for bar, avg, count in zip(bars, avgs, counts):
        ax.text(bar.get_width() + 0.05, bar.get_y() + bar.get_height() / 2,
                f"{avg:.2f} ({count})", va="center", fontsize=9)

    plt.tight_layout()
    plt.savefig(output_path, dpi=150)
    plt.close()


def write_stats(
    output_path: Path,
    df: pd.DataFrame,
    genre_counts: Counter,
    genre_stats: dict,
    fiction_counts: dict,
):
    """Write summary statistics to text file."""
    lines = []
    lines.append("=" * 60)
    lines.append("GENRE ANALYSIS SUMMARY")
    lines.append("=" * 60)
    lines.append("")

    # Overview
    lines.append("OVERVIEW")
    lines.append("-" * 40)
    lines.append(f"Total books: {len(df)}")
    lines.append(f"Unique genres: {len(genre_counts)}")
    rated_books = df[df["my_rating"] > 0]
    lines.append(f"Rated books: {len(rated_books)}")
    if len(rated_books) > 0:
        lines.append(f"Average rating: {rated_books['my_rating'].mean():.2f}")
    lines.append("")

    # Fiction vs Non-Fiction
    lines.append("FICTION VS NON-FICTION")
    lines.append("-" * 40)
    total = sum(fiction_counts.values())
    for category, count in sorted(fiction_counts.items()):
        pct = (count / total * 100) if total > 0 else 0
        lines.append(f"{category}: {count} ({pct:.1f}%)")
    lines.append("")

    # Top genres by count
    lines.append("TOP 20 GENRES BY BOOK COUNT")
    lines.append("-" * 40)
    for genre, count in genre_counts.most_common(20):
        lines.append(f"{genre}: {count}")
    lines.append("")

    # Top genres by rating (min 3 books)
    lines.append("TOP 20 GENRES BY AVERAGE RATING (min 3 books)")
    lines.append("-" * 40)
    filtered = {g: s for g, s in genre_stats.items() if s["count"] >= 3}
    sorted_by_rating = sorted(filtered.items(), key=lambda x: x[1]["avg"], reverse=True)[:20]
    for genre, stats in sorted_by_rating:
        lines.append(f"{genre}: {stats['avg']:.2f} ({stats['count']} books)")
    lines.append("")

    # Lowest rated genres
    lines.append("LOWEST RATED GENRES (min 3 books)")
    lines.append("-" * 40)
    sorted_by_rating_asc = sorted(filtered.items(), key=lambda x: x[1]["avg"])[:10]
    for genre, stats in sorted_by_rating_asc:
        lines.append(f"{genre}: {stats['avg']:.2f} ({stats['count']} books)")

    with open(output_path, "w") as f:
        f.write("\n".join(lines))


def analyze_genres(input_path: Path, output_dir: Path) -> dict:
    """
    Run full genre analysis and generate outputs.

    Returns summary statistics dict.
    """
    output_dir.mkdir(parents=True, exist_ok=True)

    # Load data
    df = load_books(input_path)

    # Compute statistics
    genre_counts = count_genres(df)
    genre_stats = rating_by_genre(df)

    # Generate plots
    plot_genre_histogram(genre_counts, output_dir / "genre_histogram.png")
    fiction_counts = plot_fiction_breakdown(df, output_dir / "fiction_breakdown.png")
    plot_rating_by_genre(genre_stats, output_dir / "rating_by_genre.png")

    # Write text summary
    write_stats(output_dir / "stats.txt", df, genre_counts, genre_stats, fiction_counts)

    return {
        "total_books": len(df),
        "unique_genres": len(genre_counts),
        "fiction_counts": fiction_counts,
    }
