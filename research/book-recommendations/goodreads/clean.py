"""Convert raw Goodreads export to clean format."""

import csv
from pathlib import Path


def clean_export(input_path: str | Path, output_path: str | Path) -> int:
    """
    Convert a raw Goodreads CSV export to a clean format.

    Only includes books marked as 'read'. Extracts key columns:
    goodreads_id, title, author, my_rating, my_review.

    Returns the number of books written.
    """
    input_path = Path(input_path)
    output_path = Path(output_path)

    fieldnames = ["goodreads_id", "title", "author", "my_rating", "my_review"]
    count = 0

    with open(input_path, "r", encoding="utf-8") as infile:
        reader = csv.DictReader(infile)

        with open(output_path, "w", encoding="utf-8", newline="") as outfile:
            writer = csv.DictWriter(outfile, fieldnames=fieldnames)
            writer.writeheader()

            for row in reader:
                if row.get("Exclusive Shelf") != "read":
                    continue

                writer.writerow({
                    "goodreads_id": row["Book Id"],
                    "title": row["Title"],
                    "author": row["Author"],
                    "my_rating": row["My Rating"],
                    "my_review": row["My Review"],
                })
                count += 1

    return count
