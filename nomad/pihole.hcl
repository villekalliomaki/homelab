job "pihole" {
    datacenters = ["home"]
    type = "service"

    affinity {
        attribute = "${attr.unique.hostname}"
        value = "marion"
        weight = 100
    }

    group "pihole" {
        count = 1

        volume "pihole" {
            type = "host"
            source = "pihole-data-pihole"
        }

        volume "dnsmasq" {
            type = "host"
            source = "pihole-data-dnsmasq"
        }

        network {
            mode = "host"

            port "http" {
                static = 8001
            }

            port "dns" {
                static = 53
            }
        }

        task "pihole" {
            driver = "docker"

            resources {
                cpu    = 200
                memory = 200
            }

            env {
                WEB_PORT = "8001"
            }

            volume_mount {
                volume = "pihole"
                destination = "/etc/pihole"
            }

            volume_mount {
                volume = "dnsmasq"
                destination = "/etc/dnsmasq.d"
            }

            config {
                # https://hub.docker.com/r/pihole/pihole/tags
                image = "pihole/pihole:2022.11.2"
                ports = ["http", "dns"]
            }
        }
    }
}