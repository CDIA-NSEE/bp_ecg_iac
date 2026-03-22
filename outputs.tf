output "minio_api_url" {
  description = "MinIO S3-compatible API URL"
  value       = "http://localhost:${var.minio_api_port}"
}

output "minio_console_url" {
  description = "MinIO web console URL"
  value       = "http://localhost:${var.minio_console_port}"
}

output "trino_jdbc_url" {
  description = "Trino JDBC connection URL"
  value       = "jdbc:trino://localhost:${var.trino_port}/nessie"
}

output "trino_http_url" {
  description = "Trino HTTP coordinator URL"
  value       = "http://localhost:${var.trino_port}"
}

output "nessie_rest_url" {
  description = "Project Nessie REST catalog URL"
  value       = "http://localhost:${var.nessie_port}"
}

output "nessie_iceberg_rest_url" {
  description = "Project Nessie Iceberg REST catalog endpoint for PyIceberg"
  value       = "http://localhost:${var.nessie_port}/iceberg"
}

output "airflow_url" {
  description = "Airflow web UI URL"
  value       = "http://localhost:${var.airflow_port}"
}

output "grafana_url" {
  description = "Grafana dashboard URL"
  value       = "http://localhost:${var.grafana_port}"
}

output "prometheus_url" {
  description = "Prometheus metrics URL"
  value       = "http://localhost:${var.prometheus_port}"
}

output "bucket_intake" {
  description = "MinIO bucket for incoming ZIP archive audit trail"
  value       = "bp-ecg-${var.environment}-intake"
}

output "bucket_images" {
  description = "MinIO bucket for processed .png.zst image files"
  value       = "bp-ecg-${var.environment}-images"
}

output "bucket_rejected" {
  description = "MinIO bucket for invalid/rejected ZIP files"
  value       = "bp-ecg-${var.environment}-rejected"
}

output "bucket_lake" {
  description = "MinIO bucket for Parquet/Iceberg tables"
  value       = "bp-ecg-${var.environment}-lake"
}

output "bucket_dlq" {
  description = "MinIO bucket for dead-letter queue (failed processing)"
  value       = "bp-ecg-${var.environment}-dlq"
}

output "docker_network" {
  description = "Docker network name shared by all services"
  value       = docker_network.lakehouse.name
}
