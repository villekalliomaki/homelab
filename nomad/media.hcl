job "media" {
    datacenters = ["home"]
    type = "service"

    # Run where the disks + GPU are
    affinity {
        attribute = "${attr.unique.hostname}"
        value = "marion"
        weight = 100
    }

    group "media" {
        count = 1

        # General data/config directories
        volume "data-jellyfin" {
            type = "host"
            source = "media-data-jellyfin"
        }
        volume "data-jfa-go" {
            type = "host"
            source = "media-data-jfa-go"
        }
        volume "data-transmission" {
            type = "host"
            source = "media-data-transmission"
        }
        volume "data-jackett" {
            type = "host"
            source = "media-data-jackett"
        }
        volume "data-radarr" {
            type = "host"
            source = "media-data-radarr"
        }
        volume "data-sonarr" {
            type = "host"
            source = "media-data-sonarr"
        }
        volume "data-bazarr" {
            type = "host"
            source = "media-data-bazarr"
        }

        # Transcoding + thumbnail cache
        volume "cache" {
            type = "host"
            source = "media-cache"
        }

        # Downloads on cache
        volume "downloads" {
            type = "host"
            source = "media-downloads"
        }

        # Actual media files and downloads
        volume "content" {
            type = "host"
            source = "media-content"
        }

        network {
            port "jellyfin" {
                static = 8096
            }

            port "jfa-go" {
                static = 8056
            }

            port "transmission" {
                static = 9091
            }

            port "radarr" {
                static = 7878
            }

            port "sonarr" {
                static = 8989
            }

            port "jackett" {
                static = 9117
            }

            port "bazarr" {
                static = 6767
            }
        }

        # Media server
        task "jellyfin" {
            driver = "docker"

            service {
                port = "jellyfin"
                provider = "nomad"
                tags = [
                    "traefik.enable=true",
                    "traefik.http.routers.jellyfin.tls=true",
                    "traefik.http.routers.jellyfin.rule=Host(`media.1fi.fi`) || Host(`media-cf.1fi.fi`)",
                    "traefik.http.routers.jellyfin.entryPoints=external_https",
                    "traefik.http.routers.jellyfin.tls.certresolver=acme"
                ]

                check {
                    type     = "http"
                    name     = "jellyfin-health"
                    path     = "/health"
                    interval = "30s"
                    timeout  = "5s"
                }
            }

            config {
                # https://hub.docker.com/r/jellyfin/jellyfin/tags
                image = "jellyfin/jellyfin:10.8.8"
                ports = ["jellyfin"]
                args = [
                    "--datadir=/data/data",
                    "--configdir=/data/config",
                    "--cachedir=/cache"
                ]
            }

            env {
                PGID = "911"
                PUID = "911"
            }

            resources {
                cpu = 6000
                memory = 4000
                device "nvidia/gpu" {
                    count = 1
                }
            }

            volume_mount {
                volume = "data-jellyfin"
                destination = "/data"
            }

            volume_mount {
                volume = "cache"
                destination = "/cache"
            }

            volume_mount {
                volume = "content"
                destination = "/content"
            }
        }

        # Jellyfin user management
        task "jfa" {
            driver = "docker"

            service {
                port = "jfa-go"
                provider = "nomad"
                tags = [
                    "traefik.enable=true",
                    "traefik.http.routers.jfa-go.tls=true",
                    "traefik.http.routers.jfa-go.rule=(Host(`media.1fi.fi`) || Host(`media-cf.1fi.fi`)) && PathPrefix(`/jfa`)",
                    "traefik.http.routers.jfa-go.entryPoints=external_https",
                    "traefik.http.routers.jfa-go.tls.certresolver=acme"
                ]
            }

            config {
                # https://hub.docker.com/r/hrfee/jfa-go/tags
                image = "hrfee/jfa-go:latest"
                ports = ["jfa-go"]
            }

            resources {
                cpu = 50
                memory = 50
            }

            volume_mount {
                volume = "data-jfa-go"
                destination = "/data"
            }

            volume_mount {
                volume = "data-jellyfin"
                destination = "/jf"
            }
        }

        # Downloads
        task "transmission" {
            driver = "docker"

            config {
                # https://hub.docker.com/r/haugene/transmission-openvpn/tags
                image = "haugene/transmission-openvpn:4.3.2"
                ports = ["transmission"]
                cap_add = ["net_admin"]
            }

            resources {
                cpu = 5000
                memory = 5000
            }

            template {
                data = <<EOH
                    {{- with secret "apps/transmission"}}
                    OPENVPN_USERNAME="{{.Data.data.providerUsername}}"
                    OPENVPN_CONFIG = "{{.Data.data.mullvadServer}}"
                    LOCAL_NETWORK="{{.Data.data.localNetworks}}"
                    TRANSMISSION_PEER_PORT= "{{.Data.data.mullvadPort}}"
                    {{- end}}
                    EOH
                destination = "/secrets/.env"
                env = true
            }

            env {
                OPENVPN_PROVIDER = "MULLVAD"
                OPENVPN_PASSWORD = "none"
                OPENVPN_OPTS= "--pull-filter ignore ifconfig-ipv6"
                TRANSMISSION_PEER_PORT_RANDOM_ON_START = "false"
                TRANSMISSION_RATIO_LIMIT = "1"
                TRANSMISSION_RATIO_LIMIT_ENABLED = "true"
                TRANSMISSION_UTP_ENABLED = "false"
                TRANSMISSION_PEER_LIMIT_GLOBAL = "1000"
                TRANSMISSION_PEER_LIMIT_PER_TORRENT = "100"
                TRANSMISSION_RPC_WHITELIST_ENABLED = "false"
                TRANSMISSION_RPC_HOST_WHITELIST_ENABLED = "false"
                TRANSMISSION_INCOMPLETE_DIR = "/downloads/incomplete"
                TRANSMISSION_INCOMPLETE_DIR_ENABLED = "true"
                TRANSMISSION_WATCH_DIR_ENABLED = "false"
                TRANSMISSION_DOWNLOAD_DIR = "/downloads/complete"
                TRANSMISSION_WEB_UI = "flood-for-transmission"
                PGID = "911"
                PUID = "911"
            }

            volume_mount {
                volume = "data-transmission"
                destination = "/config"
            }

            volume_mount {
                volume = "downloads"
                destination = "/downloads"
            }

            volume_mount {
                volume = "content"
                destination = "/content"
            }
        }

        # Movies
        task "radarr" {
            driver = "docker"

            config {
                # https://hub.docker.com/r/linuxserver/radarr/tags
                # https://github.com/Radarr/Radarr/releases
                image = "linuxserver/radarr:version-4.2.4.6635"
                ports = ["radarr"]
            }

            resources {
                cpu = 150
                memory = 300
            }

            env {
                TZ = "Europe/Helsinki"
                PGID = "911"
                PUID = "911"
            }

            volume_mount {
                volume = "data-radarr"
                destination = "/config"
            }

            volume_mount {
                volume = "downloads"
                destination = "/downloads"
            }

            volume_mount {
                volume = "content"
                destination = "/content"
            }
        }

        # Series
        task "sonarr" {
            driver = "docker"

            config {
                # https://hub.docker.com/r/linuxserver/sonarr/tags
                # https://github.com/Sonarr/Sonarr/tags
                image = "linuxserver/sonarr:version-3.0.9.1549"
                ports = ["sonarr"]
            }

            resources {
                cpu = 150
                memory = 300
            }

            env {
                TZ = "Europe/Helsinki"
                PGID = "911"
                PUID = "911"
            }

            volume_mount {
                volume = "data-sonarr"
                destination = "/config"
            }

            volume_mount {
                volume = "downloads"
                destination = "/downloads"
            }

            volume_mount {
                volume = "content"
                destination = "/content"
            }
        }

        # Trackers
        task "jackett" {
            driver = "docker"

            config {
                # https://hub.docker.com/r/linuxserver/jackett/tags
                # https://github.com/Jackett/Jackett/releases
                image = "linuxserver/jackett:0.20.2417"
                ports = ["jackett"]
            }

            resources {
                cpu = 150
                memory = 150
            }

            env {
                TZ = "Europe/Helsinki"
            }

            volume_mount {
                volume = "data-jackett"
                destination = "/config"
            }
        }

        # Subtitles
        task "bazarr" {
            driver = "docker"

            config {
                # https://hub.docker.com/r/linuxserver/bazarr/tags
                # https://github.com/morpheus65535/bazarr/releases
                image = "linuxserver/bazarr:1.1.3"
                ports = ["bazarr"]
            }

            resources {
                cpu = 150
                memory = 400
            }

            env {
                TZ = "Europe/Helsinki"
            }

            volume_mount {
                volume = "data-bazarr"
                destination = "/config"
            }

            volume_mount {
                volume = "content"
                destination = "/content"
            }
        }
    }
}