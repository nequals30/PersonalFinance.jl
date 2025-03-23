# PersonalFinance.jl
A set of utilities for dealing with personal finance.

## File Encryption
When dealing with sensitive personal financial documents, there may be a preference to keep data encrypted. For that, this library includes a tool for encrypting files:
```julia
encrypt_file("/path/to/transactions.csv")
decrypt_file("/path/to/transactions.csv")
```
This will prompt the user for a password, and the password will be valid for 15 minutes for using these encryption tools.

It can also be used to encrypt and decrypt multiple files in a systematic way:
```julia
const filePath = "/path/to/transactions.csv"

ask_password()
decrypt_file(filePath)

df = CSV.read(filePath,DataFrame)

encrypt_file(filePath, skipConfirmation=true)
```
The level of encryption is probably not sufficient enough to withstand motivated parties, but should hopefully be sufficient enough to password protect your files locally.
