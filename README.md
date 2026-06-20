# PersonalFinance.jl

A Julia package for analyzing personal finances. 

Works by loading CSVs with transactions from all accounts into one big ledger called a "Vault" (which is a SQLite database).

Then, there are tools for populating the Vault with market data and analyzing the data, including the ability to calculate net worth accurately to the penny historically.

A single script can rebuild the Vault idempotently from the CSVs, so if anything ever gets messed up or the vault is lost, it can immediately be re-built from the raw CSVs.

Also, there are built-in encryption tools, and the data can be stored in a version controlled way (e.g. with git).


## Try it

In the `examples/load_transactions/` folder, there is fake transaction data for a generic person. More information can be found in the [readme for that example](`/examples/load_transactions/`). Running the code below (from this top level directory) will create a Vault with that data:

```bash
julia --project examples/load_transactions/load_vault.jl
```

## Encryption

This library includes a tool for encrypting and decrypting files (usually the raw data CSVs):

```julia
encrypt_file("/path/to/transactions.csv")
decrypt_file("/path/to/transactions.csv")
```

If the encrypted files are version controlled, it's better to use `read_encrypted_file(...)`, which will read the contents without decrypting/re-encrypting the file.
