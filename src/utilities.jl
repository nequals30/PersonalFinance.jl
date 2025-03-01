using Nettle, SHA, Base

export encrypt_file

function encrypt_file(pathToFile::String)
	# ask for password and confirm it
	pwd = Base.getpass("Enter password")
	println()
	pwd_confirm = Base.getpass("Confirm password")

	if !isequal(pwd,pwd_confirm)
		error("Passwords do not match")
	end
	aes_encrypt(pathToFile,pwd,false)
end

function encrypt_file(pathToFile::String, password::Base.SecretBuffer; skip_confirmation=false)
	println("password is $(password)")
end

function aes_encrypt(pathToFile::String,password::Base.SecretBuffer,skip_confirmation::Bool)
	# check if file exists
	if !(isfile(pathToFile))
		error("No such file: $(pathToFile)")
	end

	if !skip_confirmation
		println("THIS WILL ENCRYPT $(pathToFile). ARE YOU SURE YOU WANT TO DO THAT? y/n")
	end
end
