# bp_ecg_iac — Datalakehouse Infrastructure

Terraform + Docker infrastructure for the **bp_ecg** local datalakehouse (CDIA-NSEE).
A single `terraform apply` provisions all services on a shared Docker bridge network.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        bp-ecg-lakehouse-net                         │
│                                                                     │
│  ┌─────────┐   ┌─────────┐   ┌────────┐   ┌──────────┐            │
│  │  MinIO  │   │  Nessie │   │ Trino  │   │ Airflow  │            │
│  │  :9000  │   │ :19120  │   │ :8080  │   │  :8081   │            │
│  └─────────┘   └─────────┘   └────────┘   └──────────┘            │
│       │              │                          │                   │
│       │         (Iceberg REST)                  │                   │
│       │              │                          │                   │
│  ┌────┴─────────────┘                      ┌────┴──────┐            │
│  │           Trino reads Nessie            │ PostgreSQL │            │
│  │           catalog + MinIO S3            │   :5432    │            │
│  └─────────────────────────────────────────└───────────┘            │
│                                                                     │
│  ┌────────────┐   ┌─────────┐                                       │
│  │ Prometheus │   │ Grafana │                                       │
│  │   :9090    │   │  :3000  │                                       │
│  └────────────┘   └─────────┘                                       │
└─────────────────────────────────────────────────────────────────────┘
```

## Services

| Service    | Image                            | Port(s)      | Purpose                          |
|------------|----------------------------------|--------------|----------------------------------|
| MinIO      | `minio/minio:latest`             | 9000, 9001   | S3-compatible object storage     |
| Nessie     | `ghcr.io/projectnessie/nessie`   | 19120        | Iceberg REST catalog             |
| Trino      | `trinodb/trino:latest`           | 8080         | SQL query engine                 |
| PostgreSQL | `postgres:16-alpine`             | (internal)   | Airflow metadata database        |
| Airflow    | `apache/airflow:3.1.6`           | 8081         | Workflow orchestration           |
| Prometheus | `prom/prometheus:latest`         | 9090         | Metrics collection               |
| Grafana    | `grafana/grafana:latest`         | 3000         | Metrics dashboards               |

## MinIO Buckets

| Bucket                        | Purpose                              |
|-------------------------------|--------------------------------------|
| `bp-ecg-{env}-intake`         | Original ZIP audit trail             |
| `bp-ecg-{env}-images`         | Processed `.png.zst` images          |
| `bp-ecg-{env}-rejected`       | Invalid/rejected ZIPs                |
| `bp-ecg-{env}-lake`           | Parquet/Iceberg tables               |
| `bp-ecg-{env}-dlq`            | Dead-letter queue (failed processing)|

## Prerequisites

- Docker Engine ≥ 24.0
- Terraform ≥ 1.5
- 8 GB RAM recommended (Trino requires ~2 GB JVM heap)

## Quick Start

```bash
# 1. Copy and edit variables
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars   # fill in passwords and data_volume_path

# 2. Ensure data volume path exists
mkdir -p /opt/bp-ecg/data

# 3. Initialize Terraform
terraform init

# 4. Preview changes
terraform plan

# 5. Apply infrastructure
terraform apply

# 6. Verify services
terraform output
```

## Rendered Files

`terraform apply` generates `.rendered/nessie.properties` from the template
`config/trino/catalog/nessie.properties.tpl` with MinIO credentials substituted.
The `.rendered/` directory is excluded from git (see `.gitignore`).

## Connecting to Services

### MinIO Console
```
URL:      http://localhost:9001
Username: <minio_root_user from tfvars>
Password: <minio_root_password from tfvars>
```

### Trino CLI
```bash
# Using the official Trino CLI
trino --server http://localhost:8080 --catalog nessie --schema bp_ecg

# Show tables
SHOW TABLES;

# Query raw records
SELECT * FROM nessie.bp_ecg.ecg_records_raw LIMIT 10;
```

### Nessie
```
REST API: http://localhost:19120
UI:       http://localhost:19120
```

### Airflow
```
URL:      http://localhost:8081
Username: <airflow_admin_user from tfvars>
Password: <airflow_admin_password from tfvars>
```

### Grafana
```
URL:      http://localhost:3000
Username: admin
Password: admin
```

## Destruction

```bash
terraform destroy
```

Named Docker volumes (`bp-ecg-minio-data`, `bp-ecg-postgres-data`, etc.) are preserved
after `terraform destroy`. To remove them:
```bash
docker volume rm bp-ecg-minio-data bp-ecg-postgres-data bp-ecg-prometheus-data bp-ecg-grafana-data
```
