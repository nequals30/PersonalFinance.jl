# Philosophy

These are the guiding ideas behind PersonalFinance.jl. They explain
*why* the API is shaped the way it is.

## Raw CSVs are the source of truth

The vault (`PersonalFinanceVault.db`) is a derived artifact. The real
data lives in the pile of statement CSVs you've downloaded over the
years from your bank, credit card issuer, brokerage, HSA, IRA, etc.
If you lose the vault, you can recompute it. If you lose the CSVs,
you've actually lost data.

This drives a lot of choices:

* Loaders are idempotent. Running the same loader on the same CSV
  any number of times produces the same database.
* There is no UI for editing transactions inside the vault. If a row
  is wrong, fix it at the source (the CSV) and reload.
* It is normal and expected to wipe the `.db` file and rebuild from
  scratch.

## One long script that rebuilds the world

Because every step (`create_vault`, `add_account`, `add_assets`,
`add_transactions`, `populate_yfinance_prices`) is idempotent, the
intended usage pattern is: each person keeps one Julia script that
does the whole build.

1. Create or open the vault.
2. Register every account and asset you have ever owned.
3. Loop over every statement CSV you have ever downloaded and call
   `add_transactions`.
4. Pull historical prices.

Run it whenever. Add a new CSV, run the script. Forget to run it for
six months, run the script. Need to nuke the vault and start over,
run the script. There is no migration step — the script *is* the
migration. It's a little Nix-flavored: the database is the build
output of (script + CSVs).

## A single ledger, not per-account silos

All transactions across all accounts live in one table. A row is
`(account, date, description, amount, asset)`. There is no separate
"checking ledger" vs. "brokerage ledger". A unified daily net-worth
time series falls out cheaply from this shape: positions are just
cumulative sums grouped by account and asset, and net worth is the
sum across all of them at that day's prices.

## Cents matter

The daily net-worth time series is meant to be accurate to the penny
for every day in your transaction history. No monthly rollups in
storage, no bucketing — aggregations happen on read, not on write.
