job "postgresql" {
  datacenters = ["home"]
  type = "service"

  affinity {
    attribute = "${attr.unique.hostname}"
    value     = "marion"
    weight    = 100
  }
}