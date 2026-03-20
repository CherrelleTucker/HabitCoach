# Inflation-Adjusted Stock Analysis Framework

## Overview

Calculate and visualize real (inflation-adjusted) stock prices using CPI data from BLS and stock prices from Yahoo Finance. **No API keys required.**

## Formula

```
Real Price = Nominal Price × (CPI_base / CPI_current)
```

Where `CPI_base` is the CPI value at a chosen reference date (typically the earliest date in your analysis or a fixed point like Jan 2020).

## Project Structure

```
stocks/
├── config.py          # Settings and defaults
├── data.py            # Data fetching (stocks + CPI)
├── adjust.py          # Inflation adjustment calculations
├── plot.py            # Visualization functions
├── main.py            # CLI entry point
└── recovery.py        # Crash recovery analysis
```

## See Also

- **[RECOVERY.md](RECOVERY.md)** — Methodology for analyzing true (inflation-adjusted) recovery times after market crashes

## Modules

### 1. config.py
- Default date ranges
- Base CPI reference date setting
- Cache settings

### 2. data.py
- `fetch_stock(ticker, start, end)` - get stock prices via yfinance
- `fetch_cpi(start, end)` - get CPI-U data from BLS (series: CUSR0000SA0)
- Handle date alignment (CPI is monthly, stocks are daily)
- Cache data locally to avoid repeated API calls

### 3. adjust.py
- `adjust_for_inflation(prices_df, cpi_df, base_date)` - convert nominal to real
- Interpolate monthly CPI to daily values for alignment
- Support different base date options

### 4. plot.py
- `plot_nominal_vs_real(ticker, df)` - side-by-side comparison
- `plot_multiple_stocks(tickers, adjusted=True)` - compare several stocks
- `plot_inflation_impact(ticker, df)` - show inflation drag over time
- Export to PNG/HTML (matplotlib for static, plotly for interactive)

### 5. main.py
- CLI interface: `uv run python -m stocks.main AAPL --start 2010-01-01`
- Support multiple tickers
- Output options: show plot, save file, print stats

## Usage Examples

```python
from stocks import fetch_stock, fetch_cpi, adjust_for_inflation, plot_nominal_vs_real

# Fetch data
stock = fetch_stock("AAPL", "2010-01-01", "2024-01-01")
cpi = fetch_cpi("2010-01-01", "2024-01-01")

# Adjust for inflation
adjusted = adjust_for_inflation(stock, cpi, base_date="2010-01-01")

# Visualize
plot_nominal_vs_real("AAPL", adjusted)
```

## CLI Usage

```bash
# Single stock with stats
uv run python -m stocks.main AAPL --stats

# Multiple stocks comparison
uv run python -m stocks.main AAPL MSFT GOOGL --start 2015-01-01

# Weighted portfolio (e.g., simulating VT with 60% US / 40% international)
uv run python -m stocks.main SPY EFA --weights "SPY:0.6,EFA:0.4" --start 2005-01-01 --stats

# Save chart
uv run python -m stocks.main AAPL --plot impact --save impact.png

# Interactive HTML chart
uv run python -m stocks.main AAPL --plot interactive --save chart.html

# Recovery analysis (see RECOVERY.md)
uv run python -m stocks.recovery
```

## Data Notes

- **CPI Source**: BLS series `CUSR0000SA0` (CPI-U, All Urban Consumers, All Items)
- **Stock Data**: Yahoo Finance via yfinance (adjusted close prices)
- **Alignment**: CPI released monthly; stocks are daily
- **Interpolation**: Linear interpolation of monthly CPI to daily values
