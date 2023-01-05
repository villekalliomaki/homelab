# Certificates

[PKI secret engine docs](https://developer.hashicorp.com/vault/api-docs/secret/pki)

[Private CA tutorial](https://developer.hashicorp.com/vault/tutorials/secrets-management/pki-engine#step-4-request-certificates)

## New role

New role for the root CA. Set `allow_bare_domains=true` for second level domains and `allow_glob_domains=true` for wildcards.

```
vault write -format=json pki/roles/domain \
    allowed_domains="domain" \
    issuer_ref="$(vault read -field=default pki/config/issuers)" \
    allow_subdomains=true \
    allow_bare_domains=true \
    allow_glob_domains=true \
    allow_ip_sans=true \
    max_ttl="90d" \
    ttl="90d"
```

## New certificate

Default TTL is the role's TTL.

```
vault write -format=json pki/issue/domain \
    common_name="domain" \
    ttl="90d" \
    alt_names="domains" \
    ip_sans="0.0.0.0"
```

## Automation

### Adding the root CA in a container

Add at a task level:

```
template {
    destination = "/secrets/ca.crt"
    data = <<EOF
        {{- with secret "pki/issuer/a61dbe37-78cb-4f2e-967c-608541e64ced" }}
        {{- .Data.certificate }}
        {{- end }}
    EOF
}
```

### Generate certificates for `marion` and `10.1.1.2`

At the task level:

```
template {
    destination = "/secrets/tls.crt"
    data = <<EOF
        {{- with secret "pki/issue/marion" "common_name=marion" "ip_sans=10.1.1.2" }}
        {{- .Data.certificate }}
        {{- end }}
        EOF
}

template {
    destination = "/secrets/tls.key"
    data = <<EOF
        {{- with secret "pki/issue/marion" "common_name=marion" "ip_sans=10.1.1.2" }}
        {{- .Data.private_key }}
        {{- end }}
        EOF
}
```
