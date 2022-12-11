# Host volume

[Example](https://developer.hashicorp.com/nomad/tutorials/stateful-workloads/stateful-workloads-host-volumes)

## Creating the volume

Add the volume to the configuration of the client (or server+client) node's config `nomad.hcl`.

```
host_volume "postgresql-data" {
    path      = "/opt/postgresql/data"
    read_only = false
}
```

Restart Nomad.

## Add volume to the job

In `group` stanza add:

```
volume "postgreql-data" {
  type      = "host"
  read_only = false
  source    = "postgresql-data"
}
```

Then add the mount configuration in the task:

```
volume_mount {
  volume      = "postgreql-data"
  destination = "/var/lib/postgresql/data"
  read_only   = false
}
```
