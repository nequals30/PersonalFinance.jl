using Preferences, SQLite

struct Vault
	db::SQLite.DB
end

function connect_vault()
	# Check if vault exists. If it doesn't start a dialogue to create it.
	if !@has_preference("vaultPath")
		println("No vault is configured yet.")
		dbPath = create_vault()
	else
		expectedDbPath = @load_preference("vaultPath")
		println("Looking for vault at $(expectedDbPath)")
		if isfile(expectedDbPath)
			dbPath = expectedDbPath
		else
			println("No vault exists at $(expectedDbPath)")
			dbPath = create_vault()
		end
	end

	return Vault(SQLite.DB(dbPath))
end

function create_vault()
	# check if the user wants to make a vault
	print("Create a new vault? [y/n]: ")
	inputPath = readline()

	if !startswith(lowercase(inputPath),"y")
		println("User chose not to make a vault. Aborting.")
		return
	
	else
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
				error("No such path exists: $(dbPath)")
			end
		end

		# create the database
		dbPath = joinpath(dbPath,"PersonalFinanceVault.db")
		print("Creating database in $(dbPath)")
		@set_preferences!("vaultPath" => dbPath)
		db = SQLite.DB(dbPath)
		SQLite.execute(db, "CREATE TABLE IF NOT EXISTS people (Name TEXT,Age INTEGER)")
	end

	return dbPath
end
