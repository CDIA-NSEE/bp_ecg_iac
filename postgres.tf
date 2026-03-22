resource "docker_image" "postgres" {
  name         = "postgres:16-alpine"
  keep_locally = true
}

resource "docker_volume" "postgres_data" {
  name = "bp-ecg-postgres-data"
}

resource "docker_container" "postgres" {
  name  = "bp-ecg-postgres"
  image = docker_image.postgres.image_id

  restart = "unless-stopped"

  networks_advanced {
    name    = docker_network.lakehouse.name
    aliases = ["postgres"]
  }

  env = [
    "POSTGRES_USER=${var.postgres_user}",
    "POSTGRES_PASSWORD=${var.postgres_password}",
    "POSTGRES_DB=${var.postgres_db}",
  ]

  volumes {
    volume_name    = docker_volume.postgres_data.name
    container_path = "/var/lib/postgresql/data"
  }

  # Run once on first DB initialisation — creates the nessie database.
  volumes {
    host_path      = "${local.module_path}/config/postgres/init.sql"
    container_path = "/docker-entrypoint-initdb.d/01-create-nessie-db.sql"
    read_only      = true
  }

  healthcheck {
    test         = ["CMD-SHELL", "pg_isready -U ${var.postgres_user} -d ${var.postgres_db}"]
    interval     = "10s"
    timeout      = "5s"
    retries      = 5
    start_period = "30s"
  }

  labels {
    label = "project"
    value = "bp-ecg"
  }
}
