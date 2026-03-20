"""CLI entry point for inflation-adjusted stock analysis."""

import argparse
import sys

from .config import DEFAULT_START_DATE, DEFAULT_BASE_DATE
from .data import fetch_stock, fetch_cpi
from .adjust import adjust_for_inflation, calculate_real_returns, combine_weighted
from .plot import (
    plot_nominal_vs_real,
    plot_nominal_vs_real_interactive,
    plot_multiple_stocks,
    plot_inflation_impact,
)


def parse_weights(weights_str: str) -> dict[str, float]:
    """Parse weights string like 'SPY:0.6,EFA:0.4' into dict."""
    weights = {}
    for pair in weights_str.split(","):
        ticker, weight = pair.strip().split(":")
        weights[ticker.strip().upper()] = float(weight.strip())
    return weights


def main():
    parser = argparse.ArgumentParser(
        description="Analyze inflation-adjusted stock prices",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  uv run python -m stocks.main AAPL
  uv run python -m stocks.main AAPL MSFT GOOGL --start 2015-01-01
  uv run python -m stocks.main AAPL --plot impact --save chart.png

  # Weighted portfolio (simulating VT before it existed):
  uv run python -m stocks.main SPY EFA --weights "SPY:0.6,EFA:0.4" --start 2005-01-01
        """,
    )

    parser.add_argument(
        "tickers",
        nargs="+",
        help="Stock ticker symbol(s) to analyze",
    )
    parser.add_argument(
        "--start",
        default=DEFAULT_START_DATE,
        help=f"Start date YYYY-MM-DD (default: {DEFAULT_START_DATE})",
    )
    parser.add_argument(
        "--end",
        default=None,
        help="End date YYYY-MM-DD (default: today)",
    )
    parser.add_argument(
        "--base-date",
        default=DEFAULT_BASE_DATE,
        help=f"Base date for inflation adjustment (default: {DEFAULT_BASE_DATE})",
    )
    parser.add_argument(
        "--weights",
        help="Combine tickers into weighted portfolio, e.g. 'SPY:0.6,EFA:0.4'",
    )
    parser.add_argument(
        "--name",
        help="Name for weighted portfolio (default: 'Portfolio')",
        default="Portfolio",
    )
    parser.add_argument(
        "--plot",
        choices=["comparison", "impact", "interactive", "multi"],
        default="comparison",
        help="Plot type (default: comparison)",
    )
    parser.add_argument(
        "--save",
        help="Save plot to file (PNG for static, HTML for interactive)",
    )
    parser.add_argument(
        "--no-show",
        action="store_true",
        help="Don't display the plot (useful with --save)",
    )
    parser.add_argument(
        "--stats",
        action="store_true",
        help="Print return statistics",
    )
    parser.add_argument(
        "--no-cache",
        action="store_true",
        help="Disable data caching",
    )

    args = parser.parse_args()

    try:
        # Fetch CPI data once
        print(f"Fetching CPI data...")
        cpi = fetch_cpi(args.start, args.end, use_cache=not args.no_cache)
        print(f"  Got {len(cpi)} monthly CPI values")

        # Fetch all stocks
        stocks = {}
        for ticker in args.tickers:
            print(f"Fetching {ticker}...")
            stock = fetch_stock(ticker, args.start, args.end, use_cache=not args.no_cache)
            print(f"  Got {len(stock)} trading days")
            stocks[ticker] = stock

        # Handle weighted portfolio
        if args.weights:
            weights = parse_weights(args.weights)
            print(f"\nCombining into weighted portfolio:")
            for ticker, weight in weights.items():
                print(f"  {ticker}: {weight*100:.0f}%")

            combined = combine_weighted(stocks, weights)
            adjusted = adjust_for_inflation(combined, cpi, args.base_date)

            if args.stats:
                returns = calculate_real_returns(adjusted)
                print(f"\n{args.name} Returns ({returns['years']:.1f} years):")
                print(f"  Nominal: {returns['nominal_total_return']*100:+.1f}% total, "
                      f"{returns['nominal_annual_return']*100:+.1f}%/year")
                print(f"  Real:    {returns['real_total_return']*100:+.1f}% total, "
                      f"{returns['real_annual_return']*100:+.1f}%/year")
                print(f"  Inflation drag: {returns['inflation_drag']*100:.1f}%")

            # Plot
            show = not args.no_show
            if args.plot == "comparison":
                plot_nominal_vs_real(args.name, adjusted, save_path=args.save, show=show)
            elif args.plot == "impact":
                plot_inflation_impact(args.name, adjusted, save_path=args.save, show=show)
            elif args.plot == "interactive":
                fig = plot_nominal_vs_real_interactive(args.name, adjusted, save_path=args.save)
                if show:
                    fig.show()

        else:
            # Process each ticker individually
            adjusted_data = {}
            for ticker, stock in stocks.items():
                adjusted = adjust_for_inflation(stock, cpi, args.base_date)
                adjusted_data[ticker] = adjusted

                if args.stats:
                    returns = calculate_real_returns(adjusted)
                    print(f"\n{ticker} Returns ({returns['years']:.1f} years):")
                    print(f"  Nominal: {returns['nominal_total_return']*100:+.1f}% total, "
                          f"{returns['nominal_annual_return']*100:+.1f}%/year")
                    print(f"  Real:    {returns['real_total_return']*100:+.1f}% total, "
                          f"{returns['real_annual_return']*100:+.1f}%/year")
                    print(f"  Inflation drag: {returns['inflation_drag']*100:.1f}%")

            # Generate plots
            show = not args.no_show

            if len(args.tickers) == 1:
                ticker = args.tickers[0]
                df = adjusted_data[ticker]

                if args.plot == "comparison":
                    plot_nominal_vs_real(ticker, df, save_path=args.save, show=show)
                elif args.plot == "impact":
                    plot_inflation_impact(ticker, df, save_path=args.save, show=show)
                elif args.plot == "interactive":
                    fig = plot_nominal_vs_real_interactive(ticker, df, save_path=args.save)
                    if show:
                        fig.show()
            else:
                # Multiple tickers
                if args.plot == "multi" or args.plot == "comparison":
                    plot_multiple_stocks(adjusted_data, adjusted=True, save_path=args.save, show=show)
                else:
                    print(f"Plot type '{args.plot}' not supported for multiple tickers, using 'multi'")
                    plot_multiple_stocks(adjusted_data, adjusted=True, save_path=args.save, show=show)

    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Unexpected error: {e}", file=sys.stderr)
        raise


if __name__ == "__main__":
    main()
