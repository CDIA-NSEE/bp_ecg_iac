resource "docker_image" "nessie" {
  name         = "ghcr.io/projectnessie/nessie:latest"
  keep_locally = true
}

resource "docker_container" "nessie" {
  name  = "bp-ecg-nessie"
  image = docker_image.nessie.image_id

  restart = "unless-stopped"

  networks_advanced {
    name    = docker_network.lakehouse.name
    aliases = ["nessie"]
  }

  ports {
    internal = 19120
    external = var.nessie_port
  }

  # Nessie uses Quarkus conventions — double-underscore translates to dot in property names.
  # Version store: JDBC backed by PostgreSQL for persistence across container restarts.
  env = [
    "NESSIE_VERSION_STORE_TYPE=JDBC",
    "QUARKUS_DATASOURCE_JDBC_URL=jdbc:postgresql://postgres:5432/${var.nessie_db}",
    "QUARKUS_DATASOURCE_USERNAME=${var.postgres_user}",
    "QUARKUS_DATASOURCE_PASSWORD=${var.postgres_password}",
    # Catalog warehouse configuration
    "NESSIE_CATALOG_DEFAULT_WAREHOUSE=warehouse",
    "NESSIE_CATALOG_WAREHOUSES_WAREHOUSE_LOCATION=s3://bp-ecg-${var.environment}-lake/",
    # S3/MinIO endpoint configuration (double-underscore = dot)
    "NESSIE_CATALOG_SERVICE_S3_DEFAULT__OPTIONS_ENDPOINT=http://minio:9000",
    "NESSIE_CATALOG_SERVICE_S3_DEFAULT__OPTIONS_PATH__STYLE__ACCESS=true",
    "NESSIE_CATALOG_SERVICE_S3_DEFAULT__OPTIONS_REGION=us-east-1",
    # Quarkus secret reference for S3 credentials
    "NESSIE_CATALOG_SERVICE_S3_DEFAULT__OPTIONS_ACCESS__KEY=urn:nessie-secret:quarkus:s3-default",
    "S3__DEFAULT_NAME=${var.minio_root_user}",
    "S3__DEFAULT_SECRET=${var.minio_root_password}",
  ]

  healthcheck {
    test         = ["CMD-SHELL", "curl -f http://localhost:19120/q/health || exit 1"]
    interval     = "15s"
    timeout      = "5s"
    retries      = 5
    start_period = "60s"
  }

  depends_on = [docker_container.minio_init, docker_container.postgres]

  labels {
    label = "project"
    value = "bp-ecg"
  }
}
