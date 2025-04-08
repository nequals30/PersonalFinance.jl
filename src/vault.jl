using Preferences, SQLite, DataFrames, Dates

export vault, add_account, list_accounts, list_units, add_transactions

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

	# load the transactions
	SQLite.execute(v.db, "BEGIN")

	stmt = SQLite.Stmt(v.db,"""
			INSERT INTO transactions (account_id, trans_date, trans_desc, amount, unit_id)
			VALUES(?, ?, ?, ?, ?)
			ON CONFLICT(account_id, trans_date, trans_desc, amount, unit_id)
			DO UPDATE SET amount = excluded.amount
	""")
	
	for (acc, date, desc, amt, unit) in zip(account_ids, dates, descriptions, amounts, unit_ids)
		SQLite.execute(stmt, (acc, date, desc, amt, unit))
	end

	SQLite.execute(v.db, "COMMIT")

	return

end

function add_account(v::Vault)
	println("Enter name for account:")
	inputAccountName = readline()

	while isempty(inputAccountName)
		inputAccountName = readline()
	end

	if !prompt_yesno("This will create account '$(inputAccountName)'. Confirm?","User chose not to create account. Aborting")
		return
	end

	SQLite.execute(v.db, """
		insert into accounts (account_name)
		values ('$(inputAccountName)')
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

function list_units(v::Vault)
	return DataFrame(Tables.columntable(DBInterface.execute(v.db,"""
		select unit_id,unit_name from units
		order by unit_id;
	   ;""")))
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
