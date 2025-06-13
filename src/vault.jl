using Preferences, SQLite, DataFrames, Dates

export vault, add_account, list_accounts, add_units, list_units, add_transactions, list_transactions, summarize_accounts

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
			unit_id INTEGER NOT NULL,
			UNIQUE(account_id, trans_date, trans_desc, amount, unit_id)
	   );""")

	SQLite.execute(db, """
		CREATE TABLE IF NOT EXISTS accounts (
			account_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
			account_name TEXT NOT NULL UNIQUE
		);""")
	

	inputUnits = prompt_input("What should the default units be?","USD")
	SQLite.execute(db, """
		CREATE TABLE IF NOT EXISTS units (
			unit_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
			unit_name TEXT NOT NULL UNIQUE
	   );""")
	SQLite.execute(db, "INSERT INTO units (unit_id,unit_name) values (1,'$inputUnits');")

	return Vault(SQLite.DB(dbPath))
end

function add_transactions(v::Vault, accounts::Union{AbstractVector{<:AbstractString},AbstractString}, dates::AbstractVector{<:Date}, descriptions::AbstractVector{<:AbstractString}, amounts::AbstractVector{<:Number}; units::Union{AbstractVector{<:AbstractString},AbstractString}="")

	# Validate accounts and look up account_ids
	accounts = isa(accounts, AbstractString) ? fill(accounts, length(dates)) : accounts
	account_ids = accountName2accountId(v, accounts)

	# Validate units and look up unit_ids
	if units === ""
		unit_ids = fill(1, length(dates))
	else
		units = isa(units, AbstractString) ? fill(units, length(dates)) : units
		unit_ids = unitName2unitId(v, units)
	end

	date_strings = string.(dates)

	# Handle Duplicates (will attach a number to the end of the description field)
	transactions = zip(account_ids, date_strings, descriptions, amounts, unit_ids)
	seen = Dict{Tuple, Int}() 
	for i in eachindex(accounts)
		# `seen` is a key value pair, where the keys are unique transactions (tuples), and the value is their count
		thisKey = (account_ids[i], date_strings[i], descriptions[i], amounts[i], unit_ids[i])
		count = get!(seen, thisKey, 0) + 1
		seen[thisKey] = count
		if count > 1
			descriptions[i] = "$(descriptions[i]) ($count)"
		end
	end

	# load the transactions
	SQLite.execute(v.db, "BEGIN")

	stmt = SQLite.Stmt(v.db,"""
			INSERT INTO transactions (account_id, trans_date, trans_desc, amount, unit_id)
			VALUES(?, ?, ?, ?, ?)
			ON CONFLICT(account_id, trans_date, trans_desc, amount, unit_id)
			DO UPDATE SET amount = excluded.amount
	""")
	
	for (acc, date, desc, amt, unit) in transactions
		SQLite.execute(stmt, (acc, date, desc, amt, unit))
	end

	SQLite.execute(v.db, "COMMIT")

	return

end

function list_transactions(v::Vault)
	tran_df = DataFrame(Tables.columntable(DBInterface.execute(v.db,"""
		select trans_id,account_name,trans_date,trans_desc,amount,unit_name
		from transactions
		left join accounts on (accounts.account_id=transactions.account_id)
		left join units on (units.unit_id=transactions.unit_id)
		order by trans_date, account_name;
		;""")))
		# where trans_desc not like '%NISA%' 

	rename!(tran_df, ["transaction_id","account_name","date","description","amount","units"])
	tran_df.date = Date.(tran_df.date, dateformat"yyyy-mm-dd")
	return tran_df
end

function add_account(v::Vault; accountName::AbstractString="", skipConfirmation::Bool=false)

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

	SQLite.execute(v.db, """
		insert into accounts (account_name)
		values ('$(accountName)')
		on conflict (account_name) do update set account_name=excluded.account_name
    ;""")
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
		select account_id, account_name from accounts
		order by account_id;
		;""")))
end

function add_units(v::Vault; unitsName::AbstractString="", skipConfirmation::Bool=false)

	if unitsName===""
		println("Enter name for units:")
		unitsName = readline()

		while isempty(unitsName)
			unitsName = readline()
		end
	end

	if ~skipConfirmation
		if !prompt_yesno("This will create units '$(unitsName)'. Confirm?","User chose not to create units. Aborting")
			return
		end
	end

	SQLite.execute(v.db, """
		insert into units (unit_name)
		values ('$(unitsName)')
		on conflict (unit_name) do update set unit_name=excluded.unit_name
    ;""")
	return
end

function list_units(v::Vault)
	return DataFrame(Tables.columntable(DBInterface.execute(v.db,"""
		select unit_id,unit_name from units
		order by unit_id;
	   ;""")))
end

function summarize_accounts(v::Vault)
	df = DataFrame(Tables.columntable(DBInterface.execute(v.db,"""
		select account_name, unit_name, sum(amount) as total_amount
		from transactions t
		right join accounts a on (a.account_id=t.account_id)
		right join units u on (u.unit_id = t.unit_id)
		group by account_name, unit_name;
		;""")))

	df = df[.!ismissing.(df.account_name),:]
	df.total_amount[abs.(df.total_amount).<0.01] .= 0

	return df
end

function unitName2unitId(v::Vault,inNames::AbstractVector{<:AbstractString})
	units_df = list_units(v)
	unit_lookup = Dict(lowercase.(units_df.unit_name) .=> units_df.unit_id)
	outIds = [get(unit_lookup, lowercase(u), missing) for u in inNames]
	if any(ismissing, outIds)
		bad_unit = inNames[findfirst(ismissing, outIds)]
		error("Units are not in the database, e.g. $bad_unit")
	end
	return outIds
end

function accountName2accountId(v::Vault,inNames::AbstractVector{<:AbstractString})
	accounts_df = list_accounts(v)
	account_lookup = Dict(lowercase.(accounts_df.account_name) .=> accounts_df.account_id)
	outIds = [get(account_lookup, lowercase(a), missing) for a in inNames]
	if any(ismissing, outIds)
		bad_unit = inNames[findfirst(ismissing, outIds)]
		error("Accounts are not in the database, e.g. $bad_unit")
	end
	return outIds
end
