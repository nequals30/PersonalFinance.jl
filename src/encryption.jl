using Nettle, SHA, Base

export encrypt_file, decrypt_file, ask_password, aes_encrypt, aes_decrypt

# Added to the file before encrypting it. Used to make sure the decrpytion password is right.
const HEADER_PASSWORD_CHECK = "PERSONALFINANCEJL"
# Added to the file after encrypting it. Used to make sure decrpytion is being run on an encrypted file.
const HEADER_I_AM_ENCRYPTED = "gflxXo8Gy54GjLch"

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

	println()

	# check if file exists
	absPath = abspath(pathToFile)
	if !(isfile(absPath))
		error("No such file: $(absPath)")
	end

	plaintext = read(absPath)

	# guardrail: make sure the file isn't already encrypted by this tool
	if startswith(String(copy(plaintext)), HEADER_I_AM_ENCRYPTED)
        error("File appears to be already encrypted with this tool. Aborting.")
    end
	plaintext_with_header = vcat(codeunits(HEADER_PASSWORD_CHECK), plaintext)

	key = sha256(read(password,String))
	Base.shred!(password)

	encrypter = Encryptor("AES256", key)
	# `iv` ensures the same data is different when encrypted twice
	iv = rand(UInt8, 16) 
	ciphertext = encrypt(encrypter, :CBC, iv, add_padding_PKCS5(plaintext_with_header,16))
	
	open(absPath, "w") do io
		write(io, HEADER_I_AM_ENCRYPTED)
		write(io, iv)
		write(io, ciphertext)
	end

	println("FILE ENCRYPTED")
	return

end

function aes_decrypt(pathToFile::String,password::Base.SecretBuffer)

	println()

	# check if file exists
	absPath = abspath(pathToFile)
	if !(isfile(absPath))
		error("No such file: $(absPath)")
	end

	data = read(absPath)

	# guardrail: check that plaintext header is there
	expectedPlaintextHeader = String(data[1:length(HEADER_I_AM_ENCRYPTED)])
	if expectedPlaintextHeader != HEADER_I_AM_ENCRYPTED
		error("File does not appear to have been encrypted by this program. Aborting.")
	end
	iv = data[(length(HEADER_I_AM_ENCRYPTED)+1):(length(HEADER_I_AM_ENCRYPTED)+16)]
	ciphertext = data[(length(HEADER_I_AM_ENCRYPTED)+17):end]

	key = sha256(read(password,String))
	Base.shred!(password)

	decrypter = Decryptor("AES256",key)
	padded_plaintext = decrypt(decrypter, :CBC, iv, ciphertext)

	# guardrail: check that the password is correct
	if !startswith(String(copy(padded_plaintext)), HEADER_PASSWORD_CHECK)
        error("Incorrect password. Aborting.")
    end

	plaintext = trim_padding_PKCS5(padded_plaintext)
    plaintext = plaintext[length(HEADER_PASSWORD_CHECK)+1:end]

	open(absPath,"w") do io
		write(io,plaintext)
	end

	println("FILE DECRYPTED")
	return
end
