job "postgresql" {

  datacenters = ["home"]
  type = "service"

  group "postgresql-server" {

    volume "postgreql-data" {
      type      = "host"
      read_only = false
      source    = "postgresql-data"
    }

    network {
      port "db" {
        
      }
    }

    task "postgresql-server" {

      config {
        # https://hub.docker.com/_/postgres
        image = "postgres:15.1-bullseye"
      }

      volume_mount {
        volume      = "postgreql-data"
        destination = "/var/lib/postgresql/data"
        read_only   = false
      }

      driver = "docker"


    } 
  }
}