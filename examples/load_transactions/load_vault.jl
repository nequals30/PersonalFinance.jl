#!/usr/bin/env julia
#
# load_vault.jl
# =============
#
# End-to-end demo of PersonalFinance.jl. Builds a fresh vault, defines
# four sample accounts and a small asset universe, loops over the CSV
# statements bundled in `examples/load_transactions/data/` and feeds
# them into add_transactions(). Then pulls market prices from Yahoo
# Finance and prints both a current snapshot and a net-worth time
# series.
#
# Run from the package root. The directory the vault lands in can be
# passed as an argument; if omitted, the script prompts interactively:
#
#     julia --project examples/load_transactions/load_vault.jl
#     julia --project examples/load_transactions/load_vault.jl /tmp/
#
# Plaintext CSVs are used here so the focus stays on the loader. A
# separate example will demonstrate keeping the same files encrypted on
# disk via encrypt_file / read_encrypted_file.

using PersonalFinance, CSV, DataFrames, Dates

const HERE     = @__DIR__
const DATA_DIR = joinpath(HERE, "data")

# ---------------------------------------------------------------------------
# Decide which directory to put the vault in. If a path is passed as a
# command-line argument it is used directly; otherwise we prompt and default
# to pwd(). create_vault() always names the file PersonalFinanceVault.db,
# so this is a directory, not a file path.
#
# Defaulting to pwd() puts the file somewhere the user owns and can hand
# to other tools (e.g. a separate UI that consumes the resulting database).
# We deliberately do NOT default to @__DIR__: when the package is installed
# via Pkg, @__DIR__ points into the read-only Julia depot.
# ---------------------------------------------------------------------------
if !isempty(ARGS)
    vault_dir = expanduser(ARGS[1])
else
    default_dir = pwd()
    print("Which directory should the vault be created in? [$default_dir]: ")
    vault_dir = let input = strip(readline())
        isempty(input) ? default_dir : expanduser(input)
    end
end
isdir(vault_dir) || error("Not a directory: $vault_dir")
vault_path = joinpath(vault_dir, "PersonalFinanceVault.db")

if isfile(vault_path)
    print("A file already exists at $vault_path. Overwrite? [y/N]: ")
    answer = lowercase(strip(readline()))
    if answer != "y" && answer != "yes"
        println("Aborting.")
        exit()
    end
    rm(vault_path)
end

v = create_vault(interactive=false, vaultPath=vault_dir)

# ---------------------------------------------------------------------------
# Accounts. The joint account has ownershipShare = 0.5, which makes
# summarize_accounts attribute only half of its balance to the user.
# ---------------------------------------------------------------------------
add_account(v, accountName="checking",       skipConfirmation=true)
add_account(v, accountName="joint-checking", skipConfirmation=true, ownershipShare=0.5)
add_account(v, accountName="credit-card",    skipConfirmation=true)
add_account(v, accountName="brokerage",      skipConfirmation=true)

# ---------------------------------------------------------------------------
# Asset universe. USD is created with the vault itself; everything else
# has to be registered before transactions can reference it.
# ---------------------------------------------------------------------------
for ticker in ("VFIAX", "VBTLX", "AAPL")
    add_assets(v, assetsName=ticker, skipConfirmation=true)
end

# ---------------------------------------------------------------------------
# Loaders. Bank-style accounts ship CSVs with (date, description, amount);
# the brokerage CSV has (date, description, units, fundName). In both
# cases the columns are handed straight to add_transactions() and any
# upsert / dedupe behavior is the vault's responsibility.
# ---------------------------------------------------------------------------
function load_bank(v, account)
    dir = joinpath(DATA_DIR, account)
    for path in sort(readdir(dir, join=true))
        df = CSV.read(path, DataFrame)
        add_transactions(v, account, df.date, df.description, df.amount)
    end
end

function load_brokerage(v, account)
    dir = joinpath(DATA_DIR, account)
    for path in sort(readdir(dir, join=true))
        df = CSV.read(path, DataFrame)
        add_transactions(v, account, df.date, df.description, df.units;
                         assets=df.fundName)
    end
end

load_bank(v,      "checking")
load_bank(v,      "joint-checking")
load_bank(v,      "credit-card")
load_brokerage(v, "brokerage")

# Pull historical market prices for everything we hold. The vault uses
# them to value share positions in the summaries below.
populate_yfinance_prices(v, ["VFIAX", "VBTLX", "AAPL"])

# ---------------------------------------------------------------------------
# Summaries.
# ---------------------------------------------------------------------------
println("\n=== current snapshot (summarize_accounts) ===")
println(summarize_accounts(v))

println("\n=== daily net worth (head and tail) ===")
mv, dts = accumulate_mv(v)
nw = DataFrame(date = dts,
               net_worth = round.(sum.(eachrow(Matrix(mv))), digits=2))
println(first(nw, 5))
println("  ...")
println(last(nw, 5))
