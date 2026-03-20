"""Find pre-crash peak and plot recovery with inflation adjustment."""

import pandas as pd
import matplotlib.pyplot as plt

from .data import fetch_stock, fetch_cpi
from .adjust import combine_weighted, adjust_for_inflation


def find_peak_before(df: pd.DataFrame, before_date: str, price_col: str = "Close") -> tuple[pd.Timestamp, float]:
    """Find the peak price before a given date."""
    mask = df.index < before_date
    subset = df.loc[mask, price_col]
    peak_date = subset.idxmax()
    peak_value = subset.max()
    return peak_date, peak_value


def plot_recovery(
    name: str,
    adjusted_df: pd.DataFrame,
    peak_date: pd.Timestamp,
    save_path: str | None = None,
    show: bool = True,
):
    """
    Plot inflation-adjusted prices with horizontal line at peak.

    Shows when the real price recovered to the pre-crash peak.
    """
    fig, ax = plt.subplots(figsize=(14, 7))

    # Get peak value (real price at peak date)
    peak_value = adjusted_df.loc[peak_date, "real_price"]

    # Plot real price
    ax.plot(adjusted_df.index, adjusted_df["real_price"],
            label="Real Price (inflation-adjusted)", color="tab:blue", linewidth=1.5)

    # Horizontal line at peak
    ax.axhline(y=peak_value, color="tab:red", linestyle="--", linewidth=2,
               label=f"Pre-crash peak ({peak_date.strftime('%Y-%m-%d')})")

    # Mark the peak point
    ax.scatter([peak_date], [peak_value], color="tab:red", s=100, zorder=5)

    # Find recovery date (first date after crash where real price >= peak)
    crash_bottom_date = adjusted_df.loc["2009-01-01":"2009-12-31", "real_price"].idxmin()
    post_crash = adjusted_df.loc[crash_bottom_date:]
    recovery_mask = post_crash["real_price"] >= peak_value

    if recovery_mask.any():
        recovery_date = post_crash.loc[recovery_mask].index[0]
        ax.axvline(x=recovery_date, color="tab:green", linestyle=":", linewidth=2,
                   label=f"Recovery date ({recovery_date.strftime('%Y-%m-%d')})")
        ax.scatter([recovery_date], [peak_value], color="tab:green", s=100, zorder=5)

        # Calculate recovery time
        years_to_recover = (recovery_date - peak_date).days / 365.25
        ax.annotate(f"{years_to_recover:.1f} years to recover",
                    xy=(recovery_date, peak_value),
                    xytext=(20, 20), textcoords="offset points",
                    fontsize=11, color="tab:green",
                    arrowprops=dict(arrowstyle="->", color="tab:green"))

    # Shade the underwater period
    underwater = adjusted_df["real_price"] < peak_value
    ax.fill_between(adjusted_df.index, adjusted_df["real_price"], peak_value,
                    where=underwater, alpha=0.2, color="red", label="Underwater")

    ax.set_xlabel("Date", fontsize=12)
    ax.set_ylabel("Price (inflation-adjusted)", fontsize=12)
    ax.set_title(f"{name}: Inflation-Adjusted Recovery from Pre-2009 Peak", fontsize=14)
    ax.legend(loc="upper left")
    ax.grid(True, alpha=0.3)

    plt.tight_layout()

    if save_path:
        plt.savefig(save_path, dpi=150)

    if show:
        plt.show()
    else:
        plt.close()

    return peak_date, peak_value


if __name__ == "__main__":
    # Fetch data (uses cache)
    print("Loading data from cache...")
    spy = fetch_stock("SPY", "2005-01-01", "2025-01-01")
    efa = fetch_stock("EFA", "2005-01-01", "2025-01-01")
    cpi = fetch_cpi("2005-01-01", "2025-01-01")

    # Combine into portfolio
    portfolio = combine_weighted(
        {"SPY": spy, "EFA": efa},
        {"SPY": 0.6, "EFA": 0.4}
    )

    # Find pre-2009 peak
    peak_date, peak_nominal = find_peak_before(portfolio, "2009-01-01")
    print(f"Pre-2009 peak: {peak_date.strftime('%Y-%m-%d')} at {peak_nominal:.2f}")

    # Adjust for inflation using peak date as base
    adjusted = adjust_for_inflation(portfolio, cpi, base_date=peak_date.strftime("%Y-%m-%d"))

    # Plot recovery
    plot_recovery("Global 60/40", adjusted, peak_date,
                  save_path="stocks/recovery_chart.png", show=False)
    print("Chart saved to stocks/recovery_chart.png")
