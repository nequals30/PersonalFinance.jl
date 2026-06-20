# Example: loading transactions

A self-contained walkthrough of PersonalFinance.jl. Loads fake but
realistic statement CSVs into a SQLite vault, fetches market prices,
and prints a current snapshot plus a daily net-worth time series.

## Running

From the package root:

```bash
julia --project examples/load_transactions/load_vault.jl
```

The script prompts for a directory to put `PersonalFinanceVault.db`
in (default is the current working directory), registers the
accounts and assets, loads the CSVs, pulls Yahoo Finance prices, and
prints a snapshot and a net-worth time series.

## The Data

There are CSVs saved in the git repo which represent the transactions of 
a US-based 30-something with:

| Account          | Type                                        | Ownership |
|------------------|---------------------------------------------|-----------|
| `checking`       | personal bank account, paycheck deposits    | 1.0       |
| `joint-checking` | shared with a partner, pays rent & groceries| 0.5       |
| `credit-card`    | day-to-day spending, paid in full monthly   | 1.0       |
| `brokerage`      | self-directed: USD, VFIAX, VBTLX, AAPL      | 1.0       |

Transactions cover 2023-01-01 through 2026-05-31, with monthly
cross-account flows (`checking → joint-checking` on the 5th and
`checking → brokerage` on the 16th).

## Regenerating the CSV fixtures

```bash
julia --project examples/load_transactions/generate_fake_data.jl
```

Wipes `data/` and rewrites every CSV from a fixed RNG seed.
