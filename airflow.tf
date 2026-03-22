resource "docker_image" "airflow" {
  name = "bp-ecg-airflow:local"
  build {
    context    = "${local.module_path}/docker"
    dockerfile = "Dockerfile.airflow"
  }
  # Rebuild the image whenever the Dockerfile changes.
  triggers = {
    dockerfile_hash = filemd5("${local.module_path}/docker/Dockerfile.airflow")
  }
  keep_locally = true
}

# One-shot init container: migrates the Airflow database and creates admin user.
# Using `airflow db check || airflow db migrate` makes this idempotent —
# on container restart, `db check` succeeds and migration is skipped.
resource "docker_container" "airflow_init" {
  name  = "bp-ecg-airflow-init"
  image = docker_image.airflow.image_id

  rm = true

  networks_advanced {
    name = docker_network.lakehouse.name
  }

  entrypoint = ["/bin/bash", "-c"]
  command = [
    join(" && ", [
      "airflow db check || airflow db migrate",
      "airflow users create --username ${var.airflow_admin_user} --password ${var.airflow_admin_password} --firstname Admin --lastname User --role Admin --email admin@bp-ecg.local || true",
      # Pre-create the minio_default connection so DAGs can reference it immediately
      "airflow connections add minio_default --conn-type aws --conn-host minio --conn-port 9000 --conn-login ${var.minio_root_user} --conn-password ${var.minio_root_password} || true",
      "echo 'Airflow initialization complete'",
    ])
  ]

  env = [
    "AIRFLOW__CORE__EXECUTOR=LocalExecutor",
    "AIRFLOW__DATABASE__SQL_ALCHEMY_CONN=postgresql+psycopg2://${var.postgres_user}:${var.postgres_password}@postgres:5432/${var.postgres_db}",
    "AIRFLOW__CORE__LOAD_EXAMPLES=False",
    "AIRFLOW__CORE__LOAD_DEFAULT_CONNECTIONS=False",
    "AIRFLOW__WEBSERVER__SECRET_KEY=${var.airflow_secret_key}",
    "AIRFLOW__LOGGING__LOGGING_LEVEL=INFO",
  ]

  depends_on = [docker_container.postgres]

  labels {
    label = "project"
    value = "bp-ecg"
  }
}

resource "docker_container" "airflow" {
  name  = "bp-ecg-airflow"
  image = docker_image.airflow.image_id

  restart = "unless-stopped"

  networks_advanced {
    name    = docker_network.lakehouse.name
    aliases = ["airflow"]
  }

  ports {
    internal = 8080
    external = var.airflow_port
  }

  # Airflow 3: start webserver + scheduler in one container (standalone mode still valid for dev)
  command = ["bash", "-c", "airflow scheduler & airflow webserver --port 8080"]

  env = [
    "AIRFLOW__CORE__EXECUTOR=LocalExecutor",
    "AIRFLOW__DATABASE__SQL_ALCHEMY_CONN=postgresql+psycopg2://${var.postgres_user}:${var.postgres_password}@postgres:5432/${var.postgres_db}",
    "AIRFLOW__CORE__LOAD_EXAMPLES=False",
    "AIRFLOW__CORE__LOAD_DEFAULT_CONNECTIONS=False",
    "AIRFLOW__CORE__DAGS_FOLDER=/opt/airflow/dags",
    "AIRFLOW__WEBSERVER__SECRET_KEY=${var.airflow_secret_key}",
    "AIRFLOW__LOGGING__LOGGING_LEVEL=INFO",
    "AIRFLOW__SCHEDULER__MIN_FILE_PROCESS_INTERVAL=30",
  ]

  # Mount DAGs directory — sourced from bp_ecg_raw_extractor repo
  volumes {
    host_path      = "${local.module_path}/../bp_ecg_raw_extractor/dags"
    container_path = "/opt/airflow/dags"
    read_only      = true
  }

  # Docker socket — required for DockerOperator to spawn extractor containers
  volumes {
    host_path      = "/var/run/docker.sock"
    container_path = "/var/run/docker.sock"
  }

  healthcheck {
    test         = ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"]
    interval     = "15s"
    timeout      = "5s"
    retries      = 10
    start_period = "90s"
  }

  depends_on = [
    docker_container.postgres,
    docker_container.airflow_init,
  ]

  labels {
    label = "project"
    value = "bp-ecg"
  }
}
