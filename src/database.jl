using Preferences, SQLite

function vault()
	# get path for database
	if !@has_preference("vaultPath")
		println("No vault is configured yet.")
		create_database()
	else
		expectedDbPath = @load_preference("vaultPath")
		println("Looking for vault at $(expectedDbPath)")
		if isfile(expectedDbPath)
			println("connect to vault")
		else
			println("No vault exists at $(expectedDbPath).")
			create_database()
		end
	end
end


function create_database()
	# ask the user if they want a vault created
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

		# figure out path where the database will go
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
		dbPath = joinpath(dbPath,"PersonalFinanceDatabase.db")
		print("Creating database in $(dbPath)")
		@set_preferences!("vaultPath" => dbPath)
		db = SQLite.DB(dbPath)
		SQLite.execute(db, "CREATE TABLE IF NOT EXISTS people (Name TEXT,Age INTEGER)")
	end
	
end
