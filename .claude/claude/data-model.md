# Data model

The vault has four tables:

* `accounts(account_id, account_name, ownership_share)`
* `assets(asset_id, asset_name)`
* `transactions(trans_id, account_id, trans_date, trans_desc, amount, asset_id)`
* `prices(asset_id, price_date, price)`

A few of the choices in there are worth flagging up front.

## USD is just another asset

There is no separate "cash" column. A USD deposit is a transaction
row with `asset = USD` and a dollar amount. A VFIAX buy is a
transaction row with `asset = VFIAX` and a fractional `amount` equal
to the share count. That means a brokerage buy is two single-sided
rows on the same date:

| date       | description | amount  | asset |
|------------|-------------|--------:|-------|
| 2025-03-17 | Buy VFIAX   | -640.00 | USD   |
| 2025-03-17 | Buy VFIAX   |   1.42  | VFIAX |

`summarize_accounts` reports one row per `(account, asset)` and
multiplies the cumulative quantity by the latest price for that
asset. `accumulate_mv` does the same for every day in history.

## Joint accounts use `ownership_share`

If two people split a checking account 50/50, the account is
registered with `ownershipShare=0.5`. The vault still stores the
full balance history; summaries multiply by the share before rolling
up to a net-worth figure. There is no per-transaction split, because
the share is a property of the account, not the individual rows.

## Cross-account transfers are two rows, not one

A transfer from checking to brokerage is two ordinary rows in two
different accounts. There is no special "transfer" record type. The
user's eyes match them up by date and amount. This keeps the schema
simple and lets transfers flow in directly from CSVs without any
special parsing.

## Idempotent loads

`add_transactions` uses `INSERT ... ON CONFLICT DO UPDATE` against a
unique constraint on
`(account_id, trans_date, trans_desc, amount, asset_id)`. Two
consequences:

* Running the same loader twice does not double-count.
* If a row already exists, the existing primary key is preserved
  rather than re-issued. That matters if anything outside the vault
  (e.g. a UI layer) holds references to transaction IDs.
