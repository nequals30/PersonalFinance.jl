using Preferences, SQLite, DataFrames, Dates

export vault, add_account, list_accounts, add_assets, list_assets, add_transactions, list_transactions, accumulate_mv, summarize_accounts, get_asset_prices

struct Vault
	db::SQLite.DB
end


function vault()
	# Check if vault exists. If it doesn't start a dialogue to create it.
	if !@has_preference("vaultPath")
		println("No vault is configured yet.")
		outVault = create_vault()
	else
		expectedDbPath = @load_preference("vaultPath")
		println("Looking for vault at $(expectedDbPath)")
		if isfile(expectedDbPath)
			dbPath = expectedDbPath
			outVault = Vault(SQLite.DB(dbPath))

		else
			println("No vault exists at $(expectedDbPath)")
			outVault = create_vault()
		end
	end

	return outVault
end

function create_vault()
	# check if the user wants to make a vault
	if !prompt_yesno("Create a new vault?","User chose not to create a vault. Aborting")
		return
	end
	println("Creating new vault...")

	# ask the user where they want the db created
	inputPath = prompt_input("Where should the database be created?",homedir())
	dbPath = expanduser(inputPath)
	if !isabspath(dbPath)
		dbPath = abspath(dbPath)
	end
	if !isdir(dirname(dbPath))
		error("No such directory exists: $(dbPath)")
	end

	# create the database
	dbPath = joinpath(dbPath,"PersonalFinanceVault.db")
	println("Creating database in $(dbPath)")
	@set_preferences!("vaultPath" => dbPath)
	db = SQLite.DB(dbPath)

	SQLite.execute(db, """
		CREATE TABLE IF NOT EXISTS transactions (
			trans_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
			account_id INTEGER NOT NULL,
			trans_date DATE NOT NULL,
			trans_desc TEXT NOT NULL,
			amount DECIMAL(7,5) NOT NULL,
			asset_id INTEGER NOT NULL,
			UNIQUE(account_id, trans_date, trans_desc, amount, asset_id)
	   );""")

	SQLite.execute(db, """
		CREATE TABLE IF NOT EXISTS accounts (
			account_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
			account_name TEXT NOT NULL UNIQUE,
			ownership_share REAL NOT NULL DEFAULT 1
		);""")

	SQLite.execute(db, """
		CREATE TABLE IF NOT EXISTS assets (
			asset_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
			asset_name TEXT NOT NULL UNIQUE
	   );""")
	inputUnits = prompt_input("What should the default asset be?","USD")
	SQLite.execute(db, "INSERT INTO assets (asset_id,asset_name) values (1,'$inputUnits');")

	SQLite.execute(db, """
		CREATE TABLE IF NOT EXISTS prices (
			asset_id INTEGER NOT NULL,
			price_date DATE NOT NULL,
			price DECIMAL(7,2) NOT NULL,
			UNIQUE(asset_id, price_date)
	   );""")

	return Vault(SQLite.DB(dbPath))
end

function add_transactions(v::Vault, accounts::Union{AbstractVector{<:AbstractString},AbstractString}, dates::AbstractVector{<:Date}, descriptions::AbstractVector{<:AbstractString}, amounts::AbstractVector{<:Number}; assets::Union{AbstractVector{<:AbstractString},AbstractString}="")

	# Validate accounts and look up account_ids
	accounts = isa(accounts, AbstractString) ? fill(accounts, length(dates)) : accounts
	account_ids = accountName2accountId(v, accounts)

	# Validate assets and look up asset_ids
	if assets === ""
		asset_ids = fill(1, length(dates))
	else
		assets = isa(assets, AbstractString) ? fill(assets, length(dates)) : assets
		asset_ids = assetName2assetId(v, assets)
	end

	date_strings = string.(dates)

	# Handle Duplicates (will attach a number to the end of the description field)
	transactions = zip(account_ids, date_strings, descriptions, amounts, asset_ids)
	seen = Dict{Tuple, Int}() 
	for i in eachindex(accounts)
		# `seen` is a key value pair, where the keys are unique transactions (tuples), and the value is their count
		thisKey = (account_ids[i], date_strings[i], descriptions[i], amounts[i], asset_ids[i])
		count = get!(seen, thisKey, 0) + 1
		seen[thisKey] = count
		if count > 1
			descriptions[i] = "$(descriptions[i]) ($count)"
		end
	end

	# load the transactions
	SQLite.execute(v.db, "BEGIN")

	stmt = SQLite.Stmt(v.db,"""
			INSERT INTO transactions (account_id, trans_date, trans_desc, amount, asset_id)
			VALUES(?, ?, ?, ?, ?)
			ON CONFLICT(account_id, trans_date, trans_desc, amount, asset_id)
			DO UPDATE SET amount = excluded.amount
	""")
	
	for (acc, date, desc, amt, asset) in transactions
		SQLite.execute(stmt, (acc, date, desc, amt, asset))
	end

	SQLite.execute(v.db, "COMMIT")

	return

end

function list_transactions(v::Vault)
	tran_df = DataFrame(Tables.columntable(DBInterface.execute(v.db,"""
		select trans_id,account_name,trans_date,trans_desc,amount,asset_name
		from transactions
		left join accounts on (accounts.account_id=transactions.account_id)
		left join assets on (assets.asset_id=transactions.asset_id)
		order by trans_date, account_name;
		;""")))

	rename!(tran_df, ["transaction_id","account_name","date","description","amount","assets"])
	tran_df.date = Date.(tran_df.date, dateformat"yyyy-mm-dd")
	return tran_df
end

function add_account(v::Vault; accountName::AbstractString="", skipConfirmation::Bool=false, ownershipShare::Float64=1.0)

	if accountName===""
		println("Enter name for account:")
		accountName = readline()

		while isempty(accountName)
			accountName = readline()
		end
	end

	if ~skipConfirmation
		if !prompt_yesno("This will create account '$(accountName)'. Confirm?","User chose not to create account. Aborting")
			return
		end
	end

	if ownershipShare == 1
		SQLite.execute(v.db, """
			insert into accounts (account_name)
			values ('$(accountName)')
			on conflict (account_name) do update set account_name=excluded.account_name
		;""")
	else
		SQLite.execute(v.db, """
			insert into accounts (account_name, ownership_share)
			values ('$(accountName)', $(ownershipShare))
			on conflict (account_name) do update set account_name=excluded.account_name, ownership_share=excluded.ownership_share
		;""")
	end
	return
end

function remove_account(v::Vault, accountName::String)
	if !prompt_yesno("This will remove account $(accountName). Are you sure?","User chose not to remove account. Aborting")
		return
	end
	# check if there are any rows in transaction table
	# if there are, confirm removal of those
	# delete account (and transactions if necessary)
end

function list_accounts(v::Vault)
	return DataFrame(Tables.columntable(DBInterface.execute(v.db,"""
		select account_id, account_name,ownership_share from accounts
		order by account_id;
		;""")))
end

function add_assets(v::Vault; assetsName::AbstractString="", skipConfirmation::Bool=false)

	if assetsName===""
		println("Enter name for assets:")
		assetsName = readline()

		while isempty(assetsName)
			assetsName = readline()
		end
	end

	if ~skipConfirmation
		if !prompt_yesno("This will create assets '$(assetsName)'. Confirm?","User chose not to create assets. Aborting")
			return
		end
	end

	SQLite.execute(v.db, """
		insert into assets (asset_name)
		values ('$(assetsName)')
		on conflict (asset_name) do update set asset_name=excluded.asset_name
    ;""")
	return
end

function get_asset_prices(v::Vault, dates::AbstractVector{<:Date}, assets::AbstractVector{<:String})

	asset_ids = assetName2assetId(v,assets)
	asset_ids_str = join(asset_ids, ",")
	start_dt = string(minimum(dates))
	end_dt = string(maximum(dates))

	q = """
		select asset_id, price_date, price
		from prices
		where price_date >= '$start_dt' and price_date <= '$end_dt'
		and asset_id in ($asset_ids_str)
		;
	"""

	prices_df = DataFrame(Tables.columntable(DBInterface.execute(v.db, q)))
	prices_df.price_date = Date.(prices_df.price_date,"yyyy-mm-dd")

	# rearrange
	asset_map = Dict(asset_ids[i] => assets[i] for i in eachindex(asset_ids))
	prices_df.asset = [asset_map[id] for id in prices_df.asset_id]
	prices_wide = unstack(prices_df, :price_date, :asset, :price)
	prices_grid = Matrix(coalesce.(prices_wide[:, Not(:price_date)], NaN))

	idxDates = [findfirst(==(d), prices_wide.price_date) for d in dates]
	idxAssets = [findfirst(==(a), names(prices_wide)[2:end]) for a in assets]
	
	isBadRow = isnothing.(idxDates)
	isBadCol = isnothing.(idxAssets)

	if all(isBadRow)
		out = fill(NaN, length(dates), length(assets))
	else
		idxDates[isBadRow] .= 1
		idxAssets[isBadCol] .= 1

		out = prices_grid[idxDates, idxAssets]
		out[isBadRow,:] .= NaN
		out[:,isBadCol] .= NaN
		
	end
	# fill prices of base currency with 1
	out[:,asset_ids.==1] .= 1

	# fill missing with stale
	
	return out

end

function list_assets(v::Vault)
	return DataFrame(Tables.columntable(DBInterface.execute(v.db,"""
		select asset_id,asset_name from assets
		order by asset_id;
	   ;""")))
end

function accumulate_mv(v::Vault)
	df = list_transactions(v)

	# add a bunch of dummy rows
	allDts = collect(minimum(df.date):Day(1):maximum(df.date))
	nDts = length(allDts)
	dummy_df = DataFrame(date = allDts,
						 account_name = fill(df.account_name[1], nDts),
						 assets = fill(df.assets[1], nDts),
						 amount = zeros(nDts) )
	df = vcat(df, dummy_df; cols=:union)

	# aggregate
    daily = combine(groupby(df, [:date, :account_name, :assets]), :amount => sum => :amount)
	daily.colname = daily.account_name .* "::" .* daily.assets
	w = unstack(daily, :date, :colname, :amount; combine=sum, fill=0)
	w = sort!(w, :date)
	w[!, 2:end] = round.(cumsum(Matrix(w[:, 2:end]); dims = 1); digits=2)

	# multiply by prices
	asset_names = String.(last.(split.(names(w)[2:end], "::")))
	prices = get_asset_prices(v, allDts, asset_names)

	out = w[:,2:end] .* prices

	return out


end

function summarize_accounts(v::Vault)
	df = DataFrame(Tables.columntable(DBInterface.execute(v.db,"""
		SELECT 
			u.asset_id,
			account_name,
			asset_name,
			SUM(amount) AS total_amount,
			ownership_share,
			CASE 
				WHEN u.asset_id = 1 THEN 1 
				ELSE p.price 
			END AS price,
			p.price_date
		FROM transactions t
		RIGHT JOIN accounts a ON a.account_id = t.account_id
		RIGHT JOIN assets u ON u.asset_id = t.asset_id
		LEFT JOIN (
			SELECT p1.asset_id, p1.price, p1.price_date
			FROM prices p1
			INNER JOIN (
				SELECT asset_id, MAX(price_date) AS max_date
				FROM prices
				GROUP BY asset_id
			) latest ON p1.asset_id = latest.asset_id AND p1.price_date = latest.max_date
		) p ON p.asset_id = u.asset_id
		GROUP BY account_name, asset_name;
		;""")))

	df = df[.!ismissing.(df.account_name),:]
	df.total_amount[abs.(df.total_amount).<0.01] .= 0
	df.market_value = df.total_amount .* df.price .* df.ownership_share

	df = df[df.total_amount.!=0,:]

	return df
end

function assetName2assetId(v::Vault,inNames::AbstractVector{<:AbstractString})
	assets_df = list_assets(v)
	asset_lookup = Dict(lowercase.(assets_df.asset_name) .=> assets_df.asset_id)
	outIds = [get(asset_lookup, lowercase(u), missing) for u in inNames]
	if any(ismissing, outIds)
		bad_asset = inNames[findfirst(ismissing, outIds)]
		error("Units are not in the database, e.g. $bad_asset")
	end
	return outIds
end

function accountName2accountId(v::Vault,inNames::AbstractVector{<:AbstractString})
	accounts_df = list_accounts(v)
	account_lookup = Dict(lowercase.(accounts_df.account_name) .=> accounts_df.account_id)
	outIds = [get(account_lookup, lowercase(a), missing) for a in inNames]
	if any(ismissing, outIds)
		bad_asset = inNames[findfirst(ismissing, outIds)]
		error("Accounts are not in the database, e.g. $bad_asset")
	end
	return outIds
end
