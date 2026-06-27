# Local secrets

Run `make setup` to generate the required secret files:

```text
db_root_password.txt
db_password.txt
wp_admin_password.txt
wp_user_password.txt
```

The generated values are 64-character hexadecimal strings created with OpenSSL. These files are ignored by Git and must remain local. Do not replace them with example credentials in the repository.
