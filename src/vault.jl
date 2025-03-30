using Preferences, SQLite, DataFrames

export vault, add_account, list_accounts

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
	println("Where should the database be created? (or press ENTER to create it in `$(homedir())/`)")
	inputPath = readline()
	if isempty(inputPath)
		dbPath = homedir()
	else
		dbPath = expanduser(inputPath)
		if !isabspath(dbPath)
			dbPath = abspath(dbPath)
		end
		if !isdir(dirname(dbPath))
			error("No such directory exists: $(dbPath)")
		end
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
			unit_id INTEGER NOT NULL
	   );""")

	SQLite.execute(db, """
		CREATE TABLE IF NOT EXISTS accounts (
			account_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
			account_name TEXT NOT NULL UNIQUE
		);""")

	return Vault(SQLite.DB(dbPath))
end

function add_transactions()
	# account(s), trans_date(s), trans_desc(s), amount(s), unit(s)
	
	# account(s) account_name (text), this should turn it into a number and validate it
	
	# unit(s) unit_name (text), this should turn it into a number and validate it

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

function list_accounts(v)
	accounts = DBInterface.execute(v.db,"""
		select account_id, account_name from accounts
		order by account_id;
		;""")
	return DataFrame(Tables.columntable(accounts))
end

