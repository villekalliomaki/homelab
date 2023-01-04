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
            port "postgresql" {
                static = 5432
            }
        }

        task "server" {
            driver = "docker"

            config {
                # https://hub.docker.com/_/postgres
                image = "postgres:15.1-bullseye"
                ports = ["postgresql"]
            }

            resources {
                cpu = 500
                memory = 500
            }

            volume_mount {
                volume = "data"
                destination = "/var/lib/postgresql/data"
            }
        } 
    }
}