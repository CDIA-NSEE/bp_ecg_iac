variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "minio_root_user" {
  description = "MinIO root username / access key"
  type        = string
  sensitive   = true
}

variable "minio_root_password" {
  description = "MinIO root password / secret key"
  type        = string
  sensitive   = true
}

variable "postgres_user" {
  description = "PostgreSQL superuser username"
  type        = string
  sensitive   = true
}

variable "postgres_password" {
  description = "PostgreSQL superuser password"
  type        = string
  sensitive   = true
}

variable "postgres_db" {
  description = "Default PostgreSQL database name (used for Airflow)"
  type        = string
  default     = "airflow"
}

variable "airflow_admin_user" {
  description = "Airflow web UI admin username"
  type        = string
  default     = "admin"
}

variable "airflow_admin_password" {
  description = "Airflow web UI admin password"
  type        = string
  sensitive   = true
}

variable "minio_api_port" {
  description = "Host port for MinIO S3-compatible API"
  type        = number
  default     = 9000
}

variable "minio_console_port" {
  description = "Host port for MinIO web console"
  type        = number
  default     = 9001
}

variable "trino_port" {
  description = "Host port for Trino coordinator HTTP"
  type        = number
  default     = 8080
}

variable "nessie_port" {
  description = "Host port for Project Nessie REST catalog"
  type        = number
  default     = 19120
}

variable "airflow_port" {
  description = "Host port for Airflow web UI"
  type        = number
  default     = 8081
}

variable "grafana_port" {
  description = "Host port for Grafana"
  type        = number
  default     = 3000
}

variable "prometheus_port" {
  description = "Host port for Prometheus"
  type        = number
  default     = 9090
}

variable "data_volume_path" {
  description = "Absolute host path for persistent data volumes (MinIO data, PostgreSQL data, etc.)"
  type        = string
}

variable "airflow_secret_key" {
  description = "Secret key for Airflow Webserver CSRF and session signing. Must be changed in production."
  type        = string
  sensitive   = true
}

variable "nessie_db" {
  description = "PostgreSQL database name used by the Nessie JDBC version store."
  type        = string
  default     = "nessie"
}
