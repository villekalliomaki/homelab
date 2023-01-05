job "postgresql" {
    datacenters = ["home"]
    type = "service"

    affinity {
        attribute = "${attr.unique.hostname}"
        value = "marion"
        weight = 100
    }

    group "postgresql" {
        count = 1

        volume "data" {
            type = "host"
            source = "postgresql-data"
        }

        network {
            port "db" {
                static = 5432
            }
        }

        task "db" {
            driver = "docker"

            config {
                # https://hub.docker.com/_/postgres
                image = "postgres:15.1"
                ports = ["db"]
                command = "postgres"
                args = [
                    "-cssl=on",
                    "-cssl_cert_file=/secrets/tls.crt",
                    "-cssl_key_file=/secrets/tls.key",
                    "-clisten_addresses=*"
                ]
            }

            service {
                port = "db"
                provider = "nomad"

                check {
                    name = "alive"
                    type = "tcp"
                    interval = "30s"
                    timeout = "5s"
                }
            }

            restart {
                attempts = 20
                interval = "2m"
                delay = "30s"
                mode = "delay"
            }

            resources {
                cpu = 500
                memory = 500
            }

            volume_mount {
                volume = "data"
                destination = "/var/lib/postgresql/data"
            }

            template {
                destination = "/secrets/tls.crt"
                perms = "600"
                uid = 999
                data = <<EOF
                    {{- with secret "pki/issue/marion" "common_name=marion" "ip_sans=10.1.1.2" }}
                    {{- .Data.certificate }}
                    {{- end }}
                    EOF
            }

            template {
                destination = "/secrets/tls.key"
                perms = "600"
                uid = 999
                data = <<EOF
                    {{- with secret "pki/issue/marion" "common_name=marion" "ip_sans=10.1.1.2" }}
                    {{- .Data.private_key }}
                    {{- end }}
                    EOF
            }

            template {
                destination = "/secrets/env"
                env = true
                data = <<EOF
                    POSTGRES_DB=root
                    POSTGRES_USER=root
                    {{- with secret "apps/postgresql" }}
                    POSTGRES_PASSWORD={{ .Data.data.superuser_password }}
                    {{- end }}
                    EOF
            }
        } 
    }
}