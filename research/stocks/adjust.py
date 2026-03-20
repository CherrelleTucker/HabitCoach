"""Inflation adjustment calculations."""

import pandas as pd
import numpy as np

from .config import DEFAULT_BASE_DATE


def interpolate_cpi_to_daily(cpi: pd.Series, target_index: pd.DatetimeIndex) -> pd.Series:
    """
    Interpolate monthly CPI values to daily values.

    Args:
        cpi: Monthly CPI series
        target_index: Daily DatetimeIndex to interpolate to

    Returns:
        Daily CPI series aligned with target_index
    """
    # Convert CPI index to datetime if needed
    cpi = cpi.copy()
    cpi.index = pd.to_datetime(cpi.index)

    # Normalize target index to timezone-naive
    target_naive = target_index.tz_localize(None) if target_index.tz else target_index

    # Create a daily date range covering the full period
    daily_range = pd.date_range(
        start=min(cpi.index.min(), target_naive.min()),
        end=max(cpi.index.max(), target_naive.max()),
        freq="D",
    )

    # Reindex CPI to daily and interpolate
    daily_cpi = cpi.reindex(daily_range).interpolate(method="linear")

    # Align with target index
    return daily_cpi.reindex(target_naive)


def adjust_for_inflation(
    stock_df: pd.DataFrame,
    cpi: pd.Series,
    base_date: str | None = None,
    price_column: str = "Close",
) -> pd.DataFrame:
    """
    Adjust stock prices for inflation.

    Args:
        stock_df: DataFrame with stock prices (from fetch_stock)
        cpi: CPI series (from fetch_cpi)
        base_date: Reference date for real prices (default from config)
        price_column: Which price column to adjust

    Returns:
        DataFrame with original data plus:
        - 'cpi': interpolated daily CPI
        - 'real_price': inflation-adjusted price
        - 'nominal_price': copy of original price for comparison
    """
    base_date = base_date or DEFAULT_BASE_DATE
    result = stock_df.copy()

    # Normalize index to timezone-naive
    if result.index.tz:
        result.index = result.index.tz_localize(None)

    # Get the stock's date index
    stock_index = result.index

    # Interpolate CPI to daily values
    daily_cpi = interpolate_cpi_to_daily(cpi, stock_index)
    result["cpi"] = daily_cpi.values

    # Get base CPI value
    base_dt = pd.Timestamp(base_date)
    if base_dt in daily_cpi.index:
        base_cpi = daily_cpi.loc[base_dt]
    else:
        # Find nearest date
        nearest_idx = daily_cpi.index.get_indexer([base_dt], method="nearest")[0]
        base_cpi = daily_cpi.iloc[nearest_idx]

    # Calculate real (inflation-adjusted) price
    # Real Price = Nominal Price × (CPI_base / CPI_current)
    result["nominal_price"] = result[price_column]
    result["real_price"] = result[price_column] * (base_cpi / result["cpi"])

    return result


def combine_weighted(
    stocks: dict[str, pd.DataFrame],
    weights: dict[str, float],
    price_column: str = "Close",
) -> pd.DataFrame:
    """
    Combine multiple stocks into a weighted portfolio.

    Args:
        stocks: Dict mapping ticker -> DataFrame (from fetch_stock)
        weights: Dict mapping ticker -> weight (should sum to 1.0)
        price_column: Which price column to use

    Returns:
        DataFrame with combined portfolio, normalized to 100 at start
    """
    # Normalize weights
    total_weight = sum(weights.values())
    weights = {k: v / total_weight for k, v in weights.items()}

    # Get all prices, normalize each to timezone-naive index
    prices = {}
    for ticker, df in stocks.items():
        df = df.copy()
        if df.index.tz:
            df.index = df.index.tz_localize(None)
        prices[ticker] = df[price_column]

    # Combine into single DataFrame, aligning on dates
    combined = pd.DataFrame(prices)

    # Only keep dates where all stocks have data
    combined = combined.dropna()

    if combined.empty:
        raise ValueError("No overlapping dates between stocks")

    # Normalize each to 100 at start date
    normalized = combined / combined.iloc[0] * 100

    # Calculate weighted portfolio value
    portfolio = pd.Series(0.0, index=normalized.index)
    for ticker, weight in weights.items():
        if ticker in normalized.columns:
            portfolio += normalized[ticker] * weight

    # Build result DataFrame matching fetch_stock output format
    result = pd.DataFrame(index=combined.index)
    result["Close"] = portfolio
    result["Open"] = portfolio
    result["High"] = portfolio
    result["Low"] = portfolio
    result["Volume"] = 0

    return result


def calculate_real_returns(
    adjusted_df: pd.DataFrame,
    period: str = "total",
) -> dict:
    """
    Calculate returns from inflation-adjusted prices.

    Args:
        adjusted_df: DataFrame from adjust_for_inflation
        period: 'total', 'annual', or 'monthly'

    Returns:
        Dict with nominal and real returns
    """
    first_nominal = adjusted_df["nominal_price"].iloc[0]
    last_nominal = adjusted_df["nominal_price"].iloc[-1]
    first_real = adjusted_df["real_price"].iloc[0]
    last_real = adjusted_df["real_price"].iloc[-1]

    nominal_return = (last_nominal - first_nominal) / first_nominal
    real_return = (last_real - first_real) / first_real

    years = (adjusted_df.index[-1] - adjusted_df.index[0]).days / 365.25

    result = {
        "nominal_total_return": nominal_return,
        "real_total_return": real_return,
        "inflation_drag": nominal_return - real_return,
        "years": years,
    }

    if period == "annual" or period == "total":
        result["nominal_annual_return"] = (1 + nominal_return) ** (1 / years) - 1
        result["real_annual_return"] = (1 + real_return) ** (1 / years) - 1

    return result
