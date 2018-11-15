vault secrets enable -version=1 kv
vault secrets enable -path=ssh-client-signer ssh
vault auth enable userpass
vault write auth/userpass/users/tester password=foo policies=admins