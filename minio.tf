resource "docker_image" "minio" {
  name         = "minio/minio:latest"
  keep_locally = true
}

resource "docker_image" "minio_mc" {
  name         = "minio/mc:latest"
  keep_locally = true
}

resource "docker_volume" "minio_data" {
  name = "bp-ecg-minio-data"
}

resource "docker_container" "minio" {
  name  = "bp-ecg-minio"
  image = docker_image.minio.image_id

  restart = "unless-stopped"

  command = ["server", "/data", "--console-address", ":9001"]

  networks_advanced {
    name    = docker_network.lakehouse.name
    aliases = ["minio"]
  }

  ports {
    internal = 9000
    external = var.minio_api_port
  }

  ports {
    internal = 9001
    external = var.minio_console_port
  }

  env = [
    "MINIO_ROOT_USER=${var.minio_root_user}",
    "MINIO_ROOT_PASSWORD=${var.minio_root_password}",
    "MINIO_PROMETHEUS_AUTH_TYPE=public",
  ]

  volumes {
    volume_name    = docker_volume.minio_data.name
    container_path = "/data"
  }

  healthcheck {
    test         = ["CMD-SHELL", "curl -f http://localhost:9000/minio/health/live || exit 1"]
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

# One-shot container that creates all required buckets after MinIO is healthy.
# Uses depends_on + the minio container healthcheck to ensure MinIO is ready.
resource "docker_container" "minio_init" {
  name  = "bp-ecg-minio-init"
  image = docker_image.minio_mc.image_id

  # Remove the container after it exits successfully
  rm = true

  networks_advanced {
    name = docker_network.lakehouse.name
  }

  entrypoint = ["/bin/sh", "-c"]
  command = [
    join(" && ", [
      "until mc alias set local http://minio:9000 ${var.minio_root_user} ${var.minio_root_password}; do sleep 2; done",
      "mc mb --ignore-existing local/bp-ecg-${var.environment}-intake",
      "mc mb --ignore-existing local/bp-ecg-${var.environment}-images",
      "mc mb --ignore-existing local/bp-ecg-${var.environment}-rejected",
      "mc mb --ignore-existing local/bp-ecg-${var.environment}-lake",
      "mc mb --ignore-existing local/bp-ecg-${var.environment}-dlq",
      "mc anonymous set download local/bp-ecg-${var.environment}-images",
      "echo 'MinIO buckets initialized successfully'",
    ])
  ]

  depends_on = [docker_container.minio]

  labels {
    label = "project"
    value = "bp-ecg"
  }
}
