# Goodreads Export Format

Guide to reading the Goodreads library export CSV.

## Source File

Raw export: `data/goodreads_export_raw.csv`

## Relevant Columns

| Column | Description |
|--------|-------------|
| `Title` | Book title |
| `My Rating` | Your rating (1-5, or `0` if unrated) |
| `My Review` | Your review text (may be empty) |
| `Exclusive Shelf` | Read status: `read`, `to-read`, `currently-reading`, `dnf` |

## Filtering for Read Books

Only process rows where:

```python
row['Exclusive Shelf'] == 'read'
```

## Quick Stats

- Total books: 829
- Read: 581
- To-read: 240
- Currently reading: 2
- DNF: 6

## Python Example

```python
import csv

with open('data/goodreads_export_raw.csv', 'r', encoding='utf-8') as f:
    reader = csv.DictReader(f)

    for row in reader:
        if row['Exclusive Shelf'] != 'read':
            continue

        title = row['Title']
        rating = int(row['My Rating'])  # 0 means unrated
        review = row['My Review']

        # Process book...
```

## Notes

- `My Rating` is a string; convert to int for comparisons
- `My Review` can be empty string even for read books
- CSV uses UTF-8 encoding
