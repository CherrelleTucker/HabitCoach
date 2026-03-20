# Inflation-Adjusted Recovery Analysis

## The Problem with Nominal Recovery

When markets crash and eventually recover, financial media typically reports the "recovery" when prices return to their previous nominal high. But this ignores inflation — if your portfolio takes 5 years to recover nominally, and inflation averaged 3% per year, you've actually lost ~15% of purchasing power.

**True recovery** = when your inflation-adjusted portfolio value returns to its pre-crash peak.

## Methodology

### 1. Find the Pre-Crash Peak

Identify the highest price point before the crash:

```python
from stocks.recovery import find_peak_before

peak_date, peak_value = find_peak_before(portfolio_df, "2009-01-01")
# Returns: 2007-10-31, 148.53
```

### 2. Pin Inflation to the Peak

Set the peak date as the CPI base date. This expresses all prices in "peak date dollars," making the peak value a horizontal reference line:

```python
from stocks import adjust_for_inflation

adjusted = adjust_for_inflation(portfolio, cpi, base_date="2007-10-31")
```

At the peak date: `real_price == nominal_price`
After inflation: `real_price < nominal_price`

### 3. Measure True Recovery

Recovery occurs when `real_price >= peak_value` after the crash bottom:

```
Peak:       2007-10-31  |  Value: 148.53
Bottom:     2009-03-09  |  Value: ~62 (58% drawdown in real terms)
Recovery:   2013-09-18  |  Value: 148.53
Time:       5.9 years underwater
```

## The Chart

```
┌─────────────────────────────────────────────────────────┐
│                                              ╭──────    │
│                                           ╭──╯          │
│  ●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━●━━━━━━━━━━━━━  │ ← Peak (horizontal line)
│ ╱ ████████████████████████████████████╱                 │
│╱  ████████████████████████████████████                  │
│   ███████ UNDERWATER █████████████╱                     │
│      ╲███████████████████████████╱                      │
│        ╲███████████████████████╱                        │
│          ╲█████████████████╱                            │
│             ╲████████████╱                              │
│                 ╲██╱                                    │
│                   ● ← Bottom                            │
└─────────────────────────────────────────────────────────┘
        2007    2009    2011    2013    2015
```

- **Red dot**: Pre-crash peak (Oct 2007)
- **Dashed red line**: Peak value in real terms
- **Red shaded area**: Underwater period
- **Green dot/line**: True recovery date (Sep 2013)

## Usage

### Command Line

```bash
# Generate recovery chart for Global 60/40 portfolio
uv run python -m stocks.recovery
```

### As Library

```python
from stocks import fetch_stock, fetch_cpi, combine_weighted, adjust_for_inflation
from stocks.recovery import find_peak_before, plot_recovery

# Build portfolio
spy = fetch_stock("SPY", "2005-01-01", "2025-01-01")
efa = fetch_stock("EFA", "2005-01-01", "2025-01-01")
cpi = fetch_cpi("2005-01-01", "2025-01-01")

portfolio = combine_weighted(
    {"SPY": spy, "EFA": efa},
    {"SPY": 0.6, "EFA": 0.4}
)

# Find peak and adjust
peak_date, _ = find_peak_before(portfolio, "2009-01-01")
adjusted = adjust_for_inflation(portfolio, cpi, base_date=peak_date.strftime("%Y-%m-%d"))

# Plot
plot_recovery("Global 60/40", adjusted, peak_date)
```

## Key Insight

The 2008 financial crisis:
- **Nominal recovery**: ~4 years (March 2009 → early 2013)
- **Real recovery**: ~5.9 years (October 2007 → September 2013)

That's nearly **2 extra years** of lost purchasing power that nominal recovery metrics hide.

## Applying to Other Crashes

The same methodology works for any crash:

| Crash | Peak Before | Suggested Cutoff |
|-------|-------------|------------------|
| 2008 GFC | 2007-10 | `"2009-01-01"` |
| 2000 Dot-com | 2000-03 | `"2002-01-01"` |
| 2020 COVID | 2020-02 | `"2020-04-01"` |
| 2022 Rate hikes | 2021-12 | `"2023-01-01"` |

```python
# Example: COVID crash recovery
peak_date, _ = find_peak_before(portfolio, "2020-04-01")
```
