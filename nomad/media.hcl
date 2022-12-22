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
            port "http-jellyfin" {
                static = 8096
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

            config {
                # https://hub.docker.com/r/jellyfin/jellyfin/tags
                image = "jellyfin/jellyfin:10.8.8"
                ports = ["http-jellyfin"]
                args = [
                    "--datadir=/data/data",
                    "--configdir=/data/config",
                    "--cachedir=/cache"
                ]
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

        // # Jellyfin user management
        // task "jfa" {
        //     config {
        //         # https://hub.docker.com/r/hrfee/jfa-go/tags
        //         image = "hrfee/jfa-go:latest"
        //     }
        // }

        # Downloads
        task "transmission" {
            driver = "docker"

            config {
                # https://hub.docker.com/r/linuxserver/transmission/tags
                image = "linuxserver/transmission:version-3.00-r6"
                ports = ["transmission"]
            }

            resources {
                cpu = 200
                memory = 200
            }

            env {
                TRANSMISSION_WEB_HOME = "/flood-for-transmission/"
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
                memory = 150
            }

            env {
                TZ = "Europe/Helsinki"
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
                memory = 150
            }

            env {
                TZ = "Europe/Helsinki"
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
                memory = 150
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