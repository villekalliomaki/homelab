job "traefik" {
    datacenters = ["home"]
    type = "service"

    # Run on Marion for internet traffic forwarding
    affinity {
        attribute = "${attr.unique.hostname}"
        value = "marion"
        # Max weight
        weight = 100
    }

    group "traefik" {
        count = 1

        network {
            port "http" {
                static = 80
            }

            port "https" {
                static = 443
            }

            port "admin-http" {
                static = 8002
            }
        }

        service {
            name = "traefik-admin"
            provider = "nomad"
            port = "admin-http"
        }

        task "proxy" {
            driver = "docker"

            # Internal TLS
            template {
                destination = "/secrets/rootCA.crt"
                data = <<EOF
                    {{ with secret "pki/issuer/a61dbe37-78cb-4f2e-967c-608541e64ced" }}
                    {{ .Data.certificate }}
                    {{ end }}
                EOF
            }

            # Config
            template {
                destination = "/secrets/traefik.yml"
                data = <<EOF
                    api:
                        dashboard: true
                        # TEMPORARY!
                        insecure: true
                    entrypoints:
                        internal_insecure:
                            address: :80
                        external_insecure:
                            address: :81
                        traefik:
                            address: :8002
                    providers:
                        nomad:
                            endpoint:
                                address: https://10.1.1.2:4646
                                token: {{ with secret "nomad/creds/service-discovery" }}{{ .Data.secret_id }}{{ end }}
                                tls:
                                    ca: /secrets/rootCA.crt
                EOF
            }

            # Environment:
            #   Nomad ACL token
            template {
                destination = "/secrets/env"
                env = true
                data = <<EOF
ACL_TOKEN={{ with secret "nomad/creds/service-discovery" }}{{ .Data.secret_id }}{{ end }}
EOF
            }

            config {
                image = "traefik:v2.9.6"
                ports = ["http", "https", "admin-http"]
                args = ["--configFile=/secrets/traefik.yml"]
            }
        }
    }
}