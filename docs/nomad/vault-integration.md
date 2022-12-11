# Vault integration

## Setting the token with Systemd

A new file `/etc/systemd/system/nomad.service.d/env.conf`:

```
[Service]
Environment="VAULT_TOKEN=token_here"
```

Systemd will load and merge the files. Note that the new file will not be read before running `systemctl daemon-reload` or restarting the node.
