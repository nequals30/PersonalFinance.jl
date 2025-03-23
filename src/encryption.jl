using Nettle, SHA, Base, Dates

export encrypt_file, decrypt_file, ask_password

# HEADER_B is added to the file before encrypting it. Used to make sure the decrpytion password is right.
# HEADER_A is added to the file after encrypting it, to make sure decrpytion is being run on an encrypted file.
# so an encrypted file looks like this: [HEADER_A, encrypted([HEADER_B, file_contents])]
const HEADER_A = "gflxXo8Gy54GjLch"
const HEADER_B = "PERSONALFINANCEJL"

const KEY_STORAGE = Dict{Symbol, Any}()
const KEY_LOCK = ReentrantLock()
const KEY_EXPIRATION_SECONDS = 10


"""
	ask_password()

Asks the user to enter a password and confirm it. Creates an expiring token in this session which lets them encrypt and decrypt files.
"""
function ask_password()
	# ask for password and confirmation
	pwd = Base.getpass("Enter password")
	println()
	pwd_confirm = Base.getpass("Confirm password")
	println()

	# if passwords don't match
	if !isequal(pwd,pwd_confirm)
		Base.shred!(pwd)
		Base.shred!(pwd_confirm)
		error("Passwords do not match")
	end

	# save the key
	key = sha256(pwd)
	Base.shred!(pwd)
	Base.shred!(pwd_confirm)
	lock(KEY_LOCK) do
		KEY_STORAGE[:key] = key
		KEY_STORAGE[:expires_at] = Dates.now() + Dates.Second(KEY_EXPIRATION_SECONDS)
	end
	start_expiration_countdown()

	return
end


function start_expiration_countdown()
	Threads.@spawn begin
		sleep(KEY_EXPIRATION_SECONDS)
		lock(KEY_LOCK) do
			if haskey(KEY_STORAGE,:expires_at) && (Dates.now()>=KEY_STORAGE[:expires_at])
				KEY_STORAGE[:key] = nothing
			end
		end
    end

	return
end


function get_key()
	lock(KEY_LOCK) do
		if haskey(KEY_STORAGE, :key) && haskey(KEY_STORAGE, :expires_at)
			if Dates.now() < KEY_STORAGE[:expires_at]
				# good
				return KEY_STORAGE[:key]
			else
				# bad. key is probably expired
				println("Encryption key has expired. Please enter your password again.")
				empty!(KEY_STORAGE)
				return nothing
			end
		end
	end
end


function check_if_the_file_exists(pathToFile::String)
	if !(isfile(pathToFile))
		error("No such file: $(pathToFile)")
	end

	return
end


"""
	encrypt_file(pathToFile::String)

Creates an interactive dialogue to encrypt the file at the specified path.
"""
function encrypt_file(pathToFile::String)
	# check if the file exists
	absPath = abspath(pathToFile)
	check_if_the_file_exists(absPath)

	# interactive confirmation
	println("\n> > > THIS WILL ENCRYPT:\n $(absPath)\n")
	if !prompt_yesno("Are you sure you want to encrypt this file?","User chose not to encrypt. Aborting.")
		return
	end

	# get the key
	key = get_key()
	if key == nothing
		ask_password()
		key = get_key()
	end

	# read the file
	println()
	plaintext = read(absPath)

	# guardrail: make sure the file isn't already encrypted by this tool
	if startswith(String(copy(plaintext)), HEADER_A)
        error("File appears to be already encrypted with this tool. Aborting.")
    end

	# attach header B to the plaintext
	plaintext_with_header = vcat(codeunits(HEADER_B), plaintext)

	# encrypt
	encrypter = Encryptor("AES256", key)
	iv = rand(UInt8, 16) 
	ciphertext = encrypt(encrypter, :CBC, iv, add_padding_PKCS5(plaintext_with_header,16))

	# write back to the file
	open(absPath, "w") do io
		write(io, HEADER_A)
		write(io, iv)
		write(io, ciphertext)
	end

	println("FILE ENCRYPTED")
	return

end


"""
	decrypt_file(pathToFile::String)

Creates an interactive dialogue to decrypt the file at the specified path.
"""
function decrypt_file(pathToFile::String)
	# check if the file exists
	absPath = abspath(pathToFile)
	check_if_the_file_exists(absPath)

	println("Decrypting file: $(absPath)")

	# get the key
	key = get_key()
	if key == nothing
		ask_password()
		key = get_key()
	end

	# read the file
	println()
	data = read(absPath)

	# guardrail: check Header A is there
	expectedPlaintextHeader = String(data[1:length(HEADER_A)])
	if expectedPlaintextHeader != HEADER_A
		error("File does not appear to have been encrypted by this program. Aborting.")
	end

	# decrypt
	iv = data[(length(HEADER_A)+1):(length(HEADER_A)+16)]
	ciphertext = data[(length(HEADER_A)+17):end]
	decrypter = Decryptor("AES256",key)
	padded_plaintext = decrypt(decrypter, :CBC, iv, ciphertext)

	# guardrail: check that the password is correct
	if !startswith(String(copy(padded_plaintext)), HEADER_B)
		empty!(KEY_STORAGE)
        error("Incorrect password. Aborting.")
    end

	plaintext = trim_padding_PKCS5(padded_plaintext)
    plaintext = plaintext[length(HEADER_B)+1:end]

	open(absPath,"w") do io
		write(io,plaintext)
	end

	println("FILE DECRYPTED")
	return
end

