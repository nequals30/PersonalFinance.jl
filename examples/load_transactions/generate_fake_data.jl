#!/usr/bin/env julia
#
# generate_fake_data.jl
# =====================
#
# One-shot script that emits realistic fake CSV statements under
# `examples/load_transactions/data/`. The committed repository already
# contains the outputs, so you do NOT need to run this to try the demo.
# It is provided so the seed data is reproducible and easy to tweak.
#
# Run from the package root:
#
#     julia --project examples/load_transactions/generate_fake_data.jl
#
# The persona is a US-based 30-something with a salaried job, a partner
# they share a checking account with, a credit card, and a self-directed
# brokerage holding VFIAX, VBTLX and AAPL. Transactions span 2023-01-01
# through 2026-05-31, with monthly transfers between checking and the
# brokerage (and between checking and the joint account) so cross-account
# flows are observable in the loaded data.

using CSV, DataFrames, Dates, Random

const HERE     = @__DIR__
const DATA_DIR = joinpath(HERE, "data")
const YEARS    = 2023:2026
const END_DATE = Date(2026, 5, 31)

# Deterministic so the output bytes are stable across regenerations.
const RNG = MersenneTwister(20260101)

# ---------------------------------------------------------------------------
# Rough prices used only when converting a dollar amount into a plausible
# share count for buy transactions. Real prices come from YFinance after
# loading; these just keep the generated share quantities visually sane.
# ---------------------------------------------------------------------------
function approx_price(ticker::AbstractString, dt::Date)
    yrs = Dates.value(dt - Date(2023, 1, 1)) / 365.0
    if     ticker == "VFIAX"; return 355.0 + 75.0 * yrs
    elseif ticker == "VBTLX"; return 9.60 + 0.40 * sin(yrs * 2pi)
    elseif ticker == "AAPL";  return 140.0 + 30.0 * yrs
    else;                     return 1.0
    end
end

function months_in_range()
    out = Tuple{Int,Int}[]
    for y in YEARS, m in 1:12
        Date(y, m, 1) <= END_DATE && push!(out, (y, m))
    end
    return out
end

# ---------------------------------------------------------------------------
# Per-account ledger builders. Each returns a Vector{NamedTuple}.
# Bank-style accounts produce (date, description, amount); the brokerage
# produces (date, description, units, fundName).
# ---------------------------------------------------------------------------
function gen_credit_card()
    merchants = [
        ("Shell Gas Station",       45.0, 15.0),
        ("BP Gas",                  42.0, 15.0),
        ("Chipotle",                13.0,  4.0),
        ("Whole Foods Market",      68.0, 25.0),
        ("Amazon.com",              42.0, 30.0),
        ("Spotify Premium",         10.99, 0.0),
        ("Netflix",                 15.99, 0.0),
        ("Steam",                   25.0, 20.0),
        ("REI Co-op",               85.0, 50.0),
        ("Blue Bottle Coffee",       6.5,  2.0),
        ("Uber Trip",               18.0, 10.0),
        ("Target",                  55.0, 30.0),
        ("Best Buy",               145.0, 60.0),
        ("Walgreens",               22.0, 12.0),
    ]
    rows = NamedTuple[]
    monthly_totals = Dict{Tuple{Int,Int},Float64}()
    for (y, m) in months_in_range()
        ndays = Dates.daysinmonth(Date(y, m, 1))
        monthly_total = 0.0
        n = 6 + rand(RNG, 0:2)
        for _ in 1:n
            d = rand(RNG, 1:min(ndays, 24))
            dt = Date(y, m, d)
            dt > END_DATE && continue
            (name, base, spread) = rand(RNG, merchants)
            amt = -round(base + (rand(RNG) - 0.5) * 2 * spread, digits=2)
            push!(rows, (date=dt, description=name, amount=amt))
            monthly_total += -amt
        end
        monthly_totals[(y, m)] = round(monthly_total, digits=2)
    end
    # Full statement balance paid from checking on the 25th of the same month.
    for ((y, m), bal) in monthly_totals
        pay_dt = Date(y, m, 25)
        pay_dt > END_DATE && continue
        push!(rows, (date=pay_dt, description="Payment from checking", amount=bal))
    end
    sort!(rows, by = r -> (r.date, r.description))
    return rows, monthly_totals
end

function gen_checking(cc_monthly)
    rows = NamedTuple[]
    for (y, m) in months_in_range()
        # Bi-monthly paychecks on the 1st and 15th.
        for d in (1, 15)
            dt = Date(y, m, d)
            dt > END_DATE && continue
            push!(rows, (date=dt, description="ACME Corp Payroll",
                         amount=round(2950 + 100 * rand(RNG), digits=2)))
        end
        dt = Date(y, m, 5)
        dt <= END_DATE && push!(rows, (date=dt,
            description="Transfer to joint-checking", amount=-1400.00))

        dt = Date(y, m, 16)
        dt <= END_DATE && push!(rows, (date=dt,
            description="Transfer to brokerage",      amount=-800.00))

        dt = Date(y, m, 20)
        dt <= END_DATE && push!(rows, (date=dt,
            description="ATM withdrawal",
            amount=-round(60 + 20 * rand(RNG), digits=2)))

        # Pay off the credit card statement on the 25th.
        dt = Date(y, m, 25)
        bal = get(cc_monthly, (y, m), 0.0)
        if dt <= END_DATE && bal > 0
            push!(rows, (date=dt, description="Credit card payment",
                         amount=-bal))
        end
    end
    # Annual tax refund in April.
    for y in YEARS
        dt = Date(y, 4, 18)
        dt > END_DATE && continue
        push!(rows, (date=dt, description="IRS tax refund",
                     amount=round(700 + 400 * rand(RNG), digits=2)))
    end
    sort!(rows, by = r -> (r.date, r.description))
    return rows
end

function gen_joint()
    rows = NamedTuple[]
    for (y, m) in months_in_range()
        # Rent on the 1st.
        dt = Date(y, m, 1)
        dt <= END_DATE && push!(rows, (date=dt,
            description="Rent - 24th Street Apartment", amount=-2000.00))

        # Contributions from both partners on the 5th.
        dt = Date(y, m, 5)
        if dt <= END_DATE
            push!(rows, (date=dt, description="Contribution from checking",
                         amount=1400.00))
            push!(rows, (date=dt, description="Contribution from partner",
                         amount=1400.00))
        end

        # Utilities on the 10th.
        dt = Date(y, m, 10)
        if dt <= END_DATE
            push!(rows, (date=dt, description="ConEd electric",
                         amount=-round(70 + 30 * rand(RNG), digits=2)))
            push!(rows, (date=dt, description="Verizon internet",
                         amount=-79.99))
        end

        # Weekly-ish groceries.
        for d in (7, 14, 21, 28)
            dt = Date(y, m, d)
            dt > END_DATE && continue
            push!(rows, (date=dt, description="Trader Joe's",
                         amount=-round(80 + 50 * rand(RNG), digits=2)))
        end

        # Monthly date night.
        dt = Date(y, m, 17)
        dt <= END_DATE && push!(rows, (date=dt,
            description="Sushi Date Night",
            amount=-round(75 + 25 * rand(RNG), digits=2)))
    end
    sort!(rows, by = r -> (r.date, r.description))
    return rows
end

function gen_brokerage()
    rows = NamedTuple[]
    for (y, m) in months_in_range()
        # Cash transfer in - mirrors checking's outflow on the 16th.
        dt = Date(y, m, 16)
        dt <= END_DATE && push!(rows, (date=dt,
            description="Transfer from checking", units=800.00, fundName="USD"))

        # 80/20 buy split on the 17th. Slightly less than the cash inflow
        # so the account accumulates a small free-cash buffer for the
        # occasional AAPL purchase.
        dt = Date(y, m, 17)
        if dt <= END_DATE
            vf_dollars = 600.00
            vb_dollars = 150.00
            vf_shares  = round(vf_dollars / approx_price("VFIAX", dt), digits=4)
            vb_shares  = round(vb_dollars / approx_price("VBTLX", dt), digits=4)
            push!(rows, (date=dt, description="Buy VFIAX", units=-vf_dollars, fundName="USD"))
            push!(rows, (date=dt, description="Buy VFIAX", units=vf_shares,   fundName="VFIAX"))
            push!(rows, (date=dt, description="Buy VBTLX", units=-vb_dollars, fundName="USD"))
            push!(rows, (date=dt, description="Buy VBTLX", units=vb_shares,   fundName="VBTLX"))
        end
    end

    # Quarterly VFIAX dividends, paid as cash.
    for y in YEARS, m in (3, 6, 9, 12)
        dt = Dates.lastdayofmonth(Date(y, m, 1))
        dt > END_DATE && continue
        push!(rows, (date=dt, description="VFIAX quarterly dividend",
                     units=round(8 + 6 * rand(RNG), digits=2), fundName="USD"))
    end

    # One AAPL buy each May.
    for y in YEARS
        dt = Date(y, 5, 20)
        dt > END_DATE && continue
        dollars = 500.00
        shares  = round(dollars / approx_price("AAPL", dt), digits=4)
        push!(rows, (date=dt, description="Buy AAPL", units=-dollars, fundName="USD"))
        push!(rows, (date=dt, description="Buy AAPL", units=shares,   fundName="AAPL"))
    end

    sort!(rows, by = r -> (r.date, r.description))
    return rows
end

# ---------------------------------------------------------------------------
# Output: split each ledger by year and write one CSV per account-year.
# ---------------------------------------------------------------------------
function write_year(account::AbstractString, year::Int, rows)
    yr_rows = filter(r -> Dates.year(r.date) == year, rows)
    isempty(yr_rows) && return
    dir = joinpath(DATA_DIR, account)
    mkpath(dir)
    path = joinpath(dir, "$(year).csv")
    CSV.write(path, DataFrame(yr_rows))
end

function main()
    # Wipe any prior demo files so the regenerated set is the only one.
    if isdir(DATA_DIR)
        for (root, _, files) in walkdir(DATA_DIR), f in files
            rm(joinpath(root, f))
        end
    end
    mkpath(DATA_DIR)

    cc_rows, cc_monthly = gen_credit_card()
    checking_rows       = gen_checking(cc_monthly)
    joint_rows          = gen_joint()
    brokerage_rows      = gen_brokerage()

    for y in YEARS
        write_year("credit-card",    y, cc_rows)
        write_year("checking",       y, checking_rows)
        write_year("joint-checking", y, joint_rows)
        write_year("brokerage",      y, brokerage_rows)
    end

    println()
    println("Wrote demo statements under: $DATA_DIR")
end

main()
