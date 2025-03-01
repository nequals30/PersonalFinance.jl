using Preferences, SQLite

export vault

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
		CREATE TABLE IF NOT EXISTS main_ledger (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			account INTEGER NOT NULL,
			dt DATE NOT NULL,
			description TEXT NOT NULL,
			amount DECIMAL(7,5) NOT NULL,
			unitId INTEGER NOT NULL
	   );""")


	return Vault(SQLite.DB(dbPath))
end

function add_to_vault()
	# account(s), date(s), description(s), amount(s)

end
