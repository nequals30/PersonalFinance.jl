using Nettle, SHA, Base

export encrypt_file, decrypt_file, ask_password, aes_encrypt, aes_decrypt

# add header to the top of file before encrypting it
# add another header to the top of file after its encrypted
# check that file is encrypted before decrypting it (by checking plaintext header)
# check that it is decrypted by the password, (by checking the encypted header) otherwise, don't override the file with the decrypted bits

function encrypt_file(pathToFile::String)

	# check if file exists
	if !(isfile(pathToFile))
		error("No such file: $(pathToFile)")
	end

	# interactive confirmation
	absPathToFile = abspath(pathToFile)
	println("\n> > > THIS WILL ENCRYPT:\n $(absPathToFile)\n")
	if !prompt_yesno("Are you sure you want to encrypt this file?","User chose not to encrypt. Aborting.")
		return
	end

	# encryption
	pwd = ask_password()
	aes_encrypt(absPathToFile,pwd)
end

function decrypt_file(pathToFile::String)

	# check if file exists
	if !(isfile(pathToFile))
		error("No such file: $(pathToFile)")
	end

	# interactive confirmation
	absPathToFile = abspath(pathToFile)
	println("Decrypting file: $(absPathToFile)")

	# encryption
	pwd = Base.getpass("Enter password")
	println()
	aes_decrypt(absPathToFile,pwd)
end

function ask_password()
	pwd = Base.getpass("Enter password")
	println()
	pwd_confirm = Base.getpass("Confirm password")
	println()

	if !isequal(pwd,pwd_confirm)
		Base.shred!(pwd)
		Base.shred!(pwd_confirm)
		error("Passwords do not match")
	end

	return pwd
end

function aes_encrypt(pathToFile::String,password::Base.SecretBuffer)
	# check if file exists
	absPath = abspath(pathToFile)
	if !(isfile(absPath))
		error("No such file: $(absPath)")
	end

	plaintext = read(absPath)

	key = sha256(read(password,String))
	Base.shred!(password)

	encrypter = Encryptor("AES256", key)
	iv = rand(UInt8, 16)
	ciphertext = encrypt(encrypter, :CBC, iv, add_padding_PKCS5(plaintext,16))
	
	open(absPath, "w") do io
		write(io, iv)
		write(io, ciphertext)
	end

	println("FILE ENCRYPTED")
	return

end

function aes_decrypt(pathToFile::String,password::Base.SecretBuffer)
	# check if file exists
	absPath = abspath(pathToFile)
	if !(isfile(absPath))
		error("No such file: $(absPath)")
	end

	data = read(absPath)
	iv = data[1:16]
	ciphertext = data[17:end]

	key = sha256(read(password,String))
	Base.shred!(password)

	decrypter = Decryptor("AES256",key)
	padded_plaintext = decrypt(decrypter, :CBC, iv, ciphertext)
	plaintext = trim_padding_PKCS5(padded_plaintext)

	open(absPath,"w") do io
		write(io,plaintext)
	end

	println("FILE DECRYPTED")
	return
end
