# Terraform test — MinIO resources only.
# Spins up the Docker network, MinIO server, and the bucket-init container,
# asserts all expected resources and outputs, then auto-destroys.
#
# Run locally: terraform test
# Scoped to MinIO so Postgres / Airflow / Trino images are never pulled.

variables {
  # Credentials — safe dummy values, this environment is ephemeral.
  minio_root_user        = "testadmin"
  minio_root_password    = "testpassword123"
  postgres_user          = "testpg"
  postgres_password      = "testpgpassword"
  airflow_admin_password = "testairflow123"
  airflow_secret_key     = "test-secret-key-for-ci"
  data_volume_path       = "/tmp/bp-ecg-test"

  environment = "dev"
}

run "minio_resources_created" {
  command = apply

  plan_options {
    target = [
      docker_network.lakehouse,
      docker_image.minio,
      docker_image.minio_mc,
      docker_volume.minio_data,
      docker_container.minio,
      docker_container.minio_init,
    ]
  }

  # ── Container basics ──────────────────────────────────────────────────────────
  assert {
    condition     = docker_container.minio.name == "bp-ecg-minio"
    error_message = "MinIO container name is '${docker_container.minio.name}', expected 'bp-ecg-minio'"
  }

  assert {
    condition     = docker_volume.minio_data.name == "bp-ecg-minio-data"
    error_message = "MinIO data volume name is '${docker_volume.minio_data.name}', expected 'bp-ecg-minio-data'"
  }

  assert {
    condition     = docker_network.lakehouse.name == "bp-ecg-lakehouse-net"
    error_message = "Docker network name is '${docker_network.lakehouse.name}', expected 'bp-ecg-lakehouse-net'"
  }

  # ── Bucket outputs ────────────────────────────────────────────────────────────
  assert {
    condition     = output.bucket_coal == "bp-ecg-dev-coal"
    error_message = "bucket_coal output is '${output.bucket_coal}', expected 'bp-ecg-dev-coal'"
  }

  assert {
    condition     = output.bucket_copper == "bp-ecg-dev-copper"
    error_message = "bucket_copper output is '${output.bucket_copper}', expected 'bp-ecg-dev-copper'"
  }

  assert {
    condition     = output.bucket_iron == "bp-ecg-dev-iron"
    error_message = "bucket_iron output is '${output.bucket_iron}', expected 'bp-ecg-dev-iron'"
  }

  assert {
    condition     = output.bucket_bronze == "bp-ecg-dev-bronze"
    error_message = "bucket_bronze output is '${output.bucket_bronze}', expected 'bp-ecg-dev-bronze'"
  }

  assert {
    condition     = output.bucket_silver == "bp-ecg-dev-silver"
    error_message = "bucket_silver output is '${output.bucket_silver}', expected 'bp-ecg-dev-silver'"
  }

  assert {
    condition     = output.bucket_gold == "bp-ecg-dev-gold"
    error_message = "bucket_gold output is '${output.bucket_gold}', expected 'bp-ecg-dev-gold'"
  }
}
