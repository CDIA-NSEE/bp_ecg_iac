resource "docker_image" "trino" {
  name         = "trinodb/trino:latest"
  keep_locally = true
}

# Render the Nessie catalog properties template with MinIO credentials.
# Using templatefile() ensures Terraform variable interpolation is applied —
# static .properties files cannot expand ${var.*} tokens.
resource "local_file" "nessie_properties" {
  content = templatefile("${local.module_path}/config/trino/catalog/nessie.properties.tpl", {
    minio_root_user     = var.minio_root_user
    minio_root_password = var.minio_root_password
  })
  filename        = "${local.module_path}/.rendered/nessie.properties"
  file_permission = "0644"
}

resource "docker_container" "trino" {
  name  = "bp-ecg-trino"
  image = docker_image.trino.image_id

  restart = "unless-stopped"

  networks_advanced {
    name    = docker_network.lakehouse.name
    aliases = ["trino"]
  }

  ports {
    internal = 8080
    external = var.trino_port
  }

  # Static Trino configuration files
  volumes {
    host_path      = "${local.module_path}/config/trino/config.properties"
    container_path = "/etc/trino/config.properties"
    read_only      = true
  }

  volumes {
    host_path      = "${local.module_path}/config/trino/node.properties"
    container_path = "/etc/trino/node.properties"
    read_only      = true
  }

  volumes {
    host_path      = "${local.module_path}/config/trino/jvm.config"
    container_path = "/etc/trino/jvm.config"
    read_only      = true
  }

  volumes {
    host_path      = "${local.module_path}/config/trino/log.properties"
    container_path = "/etc/trino/log.properties"
    read_only      = true
  }

  # Mount the rendered nessie.properties (not the .tpl source)
  volumes {
    host_path      = local_file.nessie_properties.filename
    container_path = "/etc/trino/catalog/nessie.properties"
    read_only      = true
  }

  healthcheck {
    test         = ["CMD-SHELL", "curl -f http://localhost:8080/v1/info || exit 1"]
    interval     = "15s"
    timeout      = "5s"
    retries      = 10
    start_period = "60s"
  }

  depends_on = [
    docker_container.nessie,
    docker_container.minio,
    local_file.nessie_properties,
  ]

  labels {
    label = "project"
    value = "bp-ecg"
  }
}
