# Encryption helpers

The encryption helpers (`encrypt_file`, `decrypt_file`,
`read_encrypted_file`, `ask_password`) exist so the raw statement
CSVs can sit in a version-controlled folder without being plaintext
on disk. They are deliberately *not* load-bearing for any of the
vault logic — you can use PersonalFinance.jl perfectly happily on
plaintext CSVs and ignore the encryption module entirely.

## What's protected

AES-256-CBC with a key derived from a password via SHA-256. A short
magic header tags encrypted files so the tool can refuse to
double-encrypt and can detect a wrong password without trying to
parse garbage. The password lives in process memory for 15 minutes
after `ask_password()`; after that the next call re-prompts.

This is good enough to keep casual snooping out of file backups (e.g.
a folder of statements synced to a cloud provider). It is **not** a
substitute for full-disk encryption against a motivated attacker who
has access to the machine while the password cache is warm.

## Why it's part of the package

The motivation was personal: I keep my real statement CSVs under
version control in a folder that gets backed up to places I don't
fully trust. The helpers let me commit those files without committing
plaintext financial data.
