"""Inflation-adjusted stock analysis framework."""

from .data import fetch_stock, fetch_cpi, fetch_stock_and_cpi
from .adjust import adjust_for_inflation, calculate_real_returns, combine_weighted
from .plot import (
    plot_nominal_vs_real,
    plot_nominal_vs_real_interactive,
    plot_multiple_stocks,
    plot_inflation_impact,
)

__all__ = [
    "fetch_stock",
    "fetch_cpi",
    "fetch_stock_and_cpi",
    "adjust_for_inflation",
    "calculate_real_returns",
    "combine_weighted",
    "plot_nominal_vs_real",
    "plot_nominal_vs_real_interactive",
    "plot_multiple_stocks",
    "plot_inflation_impact",
]
