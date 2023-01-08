job "redis" {
    datacenters = ["home"]
    type = "service"

    affinity {
        attribute = "${attr.unique.hostname}"
        value = "marion"
        weight = 100
    }

    group "redis" {
        count = 1

        network {

        }

        task "db" {
            
        }
    }
}