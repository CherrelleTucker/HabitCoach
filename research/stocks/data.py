"""Data fetching for stocks and CPI."""

import os
import hashlib
from datetime import datetime, timedelta

import pandas as pd
import requests
import yfinance as yf

from .config import (
    CACHE_DIR,
    CACHE_EXPIRY_DAYS,
    DEFAULT_START_DATE,
    DEFAULT_END_DATE,
)

# BLS series ID for CPI-U (All Urban Consumers, All Items)
BLS_CPI_SERIES = "CUSR0000SA0"
BLS_API_URL = "https://api.bls.gov/publicAPI/v1/timeseries/data/"


def _get_cache_path(key: str) -> str:
    """Get cache file path for a given key."""
    os.makedirs(CACHE_DIR, exist_ok=True)
    hashed = hashlib.md5(key.encode()).hexdigest()
    return os.path.join(CACHE_DIR, f"{hashed}.parquet")


def _is_cache_valid(path: str) -> bool:
    """Check if cache file exists and is not expired."""
    if not os.path.exists(path):
        return False
    mtime = datetime.fromtimestamp(os.path.getmtime(path))
    return datetime.now() - mtime < timedelta(days=CACHE_EXPIRY_DAYS)


def fetch_stock(
    ticker: str,
    start: str | None = None,
    end: str | None = None,
    use_cache: bool = True,
) -> pd.DataFrame:
    """
    Fetch stock price data from Yahoo Finance.

    Args:
        ticker: Stock symbol (e.g., "AAPL")
        start: Start date as string "YYYY-MM-DD"
        end: End date as string "YYYY-MM-DD" (default: today)
        use_cache: Whether to use cached data

    Returns:
        DataFrame with columns: Open, High, Low, Close, Volume, Dividends, Stock Splits
        Index is DatetimeIndex
    """
    start = start or DEFAULT_START_DATE
    end = end or DEFAULT_END_DATE

    cache_key = f"stock_{ticker}_{start}_{end}"
    cache_path = _get_cache_path(cache_key)

    if use_cache and _is_cache_valid(cache_path):
        return pd.read_parquet(cache_path)

    stock = yf.Ticker(ticker)
    df = stock.history(start=start, end=end)

    if df.empty:
        raise ValueError(f"No data found for ticker: {ticker}")

    if use_cache:
        df.to_parquet(cache_path)

    return df


def fetch_cpi(
    start: str | None = None,
    end: str | None = None,
    use_cache: bool = True,
) -> pd.Series:
    """
    Fetch CPI data from BLS (Bureau of Labor Statistics).

    No API key required - uses the public API.

    Args:
        start: Start date as string "YYYY-MM-DD"
        end: End date as string "YYYY-MM-DD" (default: today)
        use_cache: Whether to use cached data

    Returns:
        Series with CPI values, indexed by date (monthly)
    """
    start = start or DEFAULT_START_DATE
    end = end or DEFAULT_END_DATE

    cache_key = f"cpi_bls_{start}_{end}"
    cache_path = _get_cache_path(cache_key)

    if use_cache and _is_cache_valid(cache_path):
        df = pd.read_parquet(cache_path)
        return df["cpi"]

    start_year = int(start[:4])
    end_year = int(end[:4]) if end else datetime.now().year

    # BLS API v1 (no key) allows max 10 years per request
    all_data = []
    for chunk_start in range(start_year, end_year + 1, 10):
        chunk_end = min(chunk_start + 9, end_year)

        response = requests.post(
            BLS_API_URL,
            json={
                "seriesid": [BLS_CPI_SERIES],
                "startyear": str(chunk_start),
                "endyear": str(chunk_end),
            },
            headers={"Content-Type": "application/json"},
        )
        response.raise_for_status()

        result = response.json()
        if result["status"] != "REQUEST_SUCCEEDED":
            raise ValueError(f"BLS API error: {result.get('message', 'Unknown error')}")

        series_data = result["Results"]["series"][0]["data"]
        all_data.extend(series_data)

    # Parse into DataFrame
    records = []
    for item in all_data:
        # BLS uses M01-M12 for months, M13 for annual average
        period = item["period"]
        if not period.startswith("M") or period == "M13":
            continue
        # Skip invalid values
        try:
            value = float(item["value"])
        except (ValueError, TypeError):
            continue
        month = int(period[1:])
        year = int(item["year"])
        date = datetime(year, month, 1)
        records.append({"date": date, "cpi": value})

    df = pd.DataFrame(records)
    df = df.drop_duplicates(subset=["date"])
    df = df.set_index("date").sort_index()

    # Filter to requested date range
    if start:
        df = df[df.index >= start]
    if end:
        df = df[df.index <= end]

    if df.empty:
        raise ValueError("No CPI data found for the given date range")

    cpi = df["cpi"]
    cpi.name = "cpi"

    if use_cache:
        df.to_parquet(cache_path)

    return cpi


def fetch_stock_and_cpi(
    ticker: str,
    start: str | None = None,
    end: str | None = None,
    use_cache: bool = True,
) -> tuple[pd.DataFrame, pd.Series]:
    """
    Convenience function to fetch both stock and CPI data.

    Returns:
        Tuple of (stock_df, cpi_series)
    """
    stock = fetch_stock(ticker, start, end, use_cache)
    cpi = fetch_cpi(start, end, use_cache)
    return stock, cpi
