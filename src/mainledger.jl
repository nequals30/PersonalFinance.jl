using SQLite

function create_database()
	# check if SQLite database exists, if not, create it, if it does, check it
	println("Creating Database...")
	db = SQLite.DB("PersonalFinanceDatabase.db")
	SQLite.execute(db, "CREATE TABLE IF NOT EXISTS people (Name TEXT,Age INTEGER)")
end
