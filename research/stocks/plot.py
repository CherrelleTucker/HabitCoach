"""Visualization functions for stock analysis."""

from pathlib import Path

import pandas as pd
import matplotlib.pyplot as plt
import plotly.graph_objects as go
from plotly.subplots import make_subplots


def plot_nominal_vs_real(
    ticker: str,
    adjusted_df: pd.DataFrame,
    save_path: str | None = None,
    show: bool = True,
) -> None:
    """
    Plot nominal vs real (inflation-adjusted) stock prices.

    Args:
        ticker: Stock symbol for title
        adjusted_df: DataFrame from adjust_for_inflation
        save_path: Optional path to save the figure
        show: Whether to display the plot
    """
    fig, ax = plt.subplots(figsize=(12, 6))

    ax.plot(adjusted_df.index, adjusted_df["nominal_price"], label="Nominal Price", alpha=0.8)
    ax.plot(adjusted_df.index, adjusted_df["real_price"], label="Real Price (Inflation-Adjusted)", alpha=0.8)

    ax.set_xlabel("Date")
    ax.set_ylabel("Price ($)")
    ax.set_title(f"{ticker}: Nominal vs Inflation-Adjusted Price")
    ax.legend()
    ax.grid(True, alpha=0.3)

    plt.tight_layout()

    if save_path:
        plt.savefig(save_path, dpi=150)

    if show:
        plt.show()
    else:
        plt.close()


def plot_nominal_vs_real_interactive(
    ticker: str,
    adjusted_df: pd.DataFrame,
    save_path: str | None = None,
) -> go.Figure:
    """
    Create interactive plotly chart of nominal vs real prices.

    Args:
        ticker: Stock symbol for title
        adjusted_df: DataFrame from adjust_for_inflation
        save_path: Optional path to save HTML

    Returns:
        Plotly Figure object
    """
    fig = go.Figure()

    fig.add_trace(go.Scatter(
        x=adjusted_df.index,
        y=adjusted_df["nominal_price"],
        name="Nominal Price",
        line=dict(color="blue"),
    ))

    fig.add_trace(go.Scatter(
        x=adjusted_df.index,
        y=adjusted_df["real_price"],
        name="Real Price (Inflation-Adjusted)",
        line=dict(color="red"),
    ))

    fig.update_layout(
        title=f"{ticker}: Nominal vs Inflation-Adjusted Price",
        xaxis_title="Date",
        yaxis_title="Price ($)",
        hovermode="x unified",
        template="plotly_white",
    )

    if save_path:
        fig.write_html(save_path)

    return fig


def plot_multiple_stocks(
    data: dict[str, pd.DataFrame],
    adjusted: bool = True,
    normalize: bool = True,
    save_path: str | None = None,
    show: bool = True,
) -> None:
    """
    Plot multiple stocks on the same chart.

    Args:
        data: Dict mapping ticker -> adjusted DataFrame
        adjusted: If True, plot real prices; if False, plot nominal
        normalize: If True, normalize all to 100 at start date
        save_path: Optional path to save the figure
        show: Whether to display the plot
    """
    fig, ax = plt.subplots(figsize=(12, 6))

    price_col = "real_price" if adjusted else "nominal_price"

    for ticker, df in data.items():
        prices = df[price_col]
        if normalize:
            prices = (prices / prices.iloc[0]) * 100
        ax.plot(df.index, prices, label=ticker, alpha=0.8)

    ylabel = "Normalized Price (Start = 100)" if normalize else "Price ($)"
    title_suffix = "Inflation-Adjusted" if adjusted else "Nominal"

    ax.set_xlabel("Date")
    ax.set_ylabel(ylabel)
    ax.set_title(f"Stock Comparison ({title_suffix})")
    ax.legend()
    ax.grid(True, alpha=0.3)

    plt.tight_layout()

    if save_path:
        plt.savefig(save_path, dpi=150)

    if show:
        plt.show()
    else:
        plt.close()


def plot_inflation_impact(
    ticker: str,
    adjusted_df: pd.DataFrame,
    save_path: str | None = None,
    show: bool = True,
) -> None:
    """
    Plot showing the cumulative impact of inflation on returns.

    Args:
        ticker: Stock symbol for title
        adjusted_df: DataFrame from adjust_for_inflation
        save_path: Optional path to save the figure
        show: Whether to display the plot
    """
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(12, 8))

    # Top plot: prices
    ax1.plot(adjusted_df.index, adjusted_df["nominal_price"], label="Nominal", alpha=0.8)
    ax1.plot(adjusted_df.index, adjusted_df["real_price"], label="Real", alpha=0.8)
    ax1.fill_between(
        adjusted_df.index,
        adjusted_df["real_price"],
        adjusted_df["nominal_price"],
        alpha=0.3,
        label="Inflation Drag",
    )
    ax1.set_ylabel("Price ($)")
    ax1.set_title(f"{ticker}: Inflation Impact on Stock Price")
    ax1.legend()
    ax1.grid(True, alpha=0.3)

    # Bottom plot: percentage difference
    pct_diff = ((adjusted_df["nominal_price"] - adjusted_df["real_price"])
                / adjusted_df["nominal_price"] * 100)
    ax2.fill_between(adjusted_df.index, 0, pct_diff, alpha=0.5, color="red")
    ax2.set_xlabel("Date")
    ax2.set_ylabel("Inflation Drag (%)")
    ax2.set_title("Cumulative Inflation Impact as % of Nominal Price")
    ax2.grid(True, alpha=0.3)

    plt.tight_layout()

    if save_path:
        plt.savefig(save_path, dpi=150)

    if show:
        plt.show()
    else:
        plt.close()
