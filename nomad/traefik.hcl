job "traefik" {
    datacenters = ["home"]
    type = "service"

    # Internet traffic forwarded to marion external ports
    # Private networks use the internal ports
    affinity {
        attribute = "${attr.unique.hostname}"
        value = "marion"
        weight = 100
    }

    group "traefik" {
        count = 1

        volume "traefik" {
            type = "host"
            source = "traefik"
        }

        network {
            port "http-internal" {
                static = 80
            }

            port "https-internal" {
                static = 443
            }

            port "http-external" {
                static = 81
            }

            port "https-external" {
                static = 444
            }

            port "http-admin" {
                static = 8002
            }
        }

        task "proxy" {
            driver = "docker"

            volume_mount {
                volume = "traefik"
                destination = "/data"
            }

            # Internal TLS
            template {
                destination = "/secrets/rootCA.crt"
                data = <<EOF
                    {{- with secret "pki/issuer/a61dbe37-78cb-4f2e-967c-608541e64ced" }}
                    {{- .Data.certificate }}
                    {{- end }}
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
                        internal_http:
                            address: :80
                        internal_https:
                            address: :443
                        external_http:
                            address: :81
                        external_https:
                            address: :444
                        traefik:
                            address: :8002
                    certificatesResolvers:
                        acme:
                            acme:
                                email: {{ with secret "apps/general" }}{{ .Data.data.email }}{{ end }}
                                storage: /data/acme.json
                                httpChallenge:
                                    entryPoint: external_http
                    providers:
                        nomad:
                            endpoint:
                                address: https://10.1.1.2:4646
                                token: {{ with secret "nomad/creds/service-discovery" }}{{ .Data.secret_id }}{{ end }}
                                tls:
                                    ca: /secrets/rootCA.crt
                EOF
            }

            config {
                image = "traefik:v2.9.6"
                ports = ["http-internal", "https-internal", "http-external", "https-external", "http-admin"]
                args = ["--configFile=/secrets/traefik.yml"]
            }
        }
    }
}