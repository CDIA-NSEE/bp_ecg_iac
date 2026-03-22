resource "docker_image" "prometheus" {
  name         = "prom/prometheus:latest"
  keep_locally = true
}

resource "docker_image" "grafana" {
  name         = "grafana/grafana:latest"
  keep_locally = true
}

resource "docker_volume" "prometheus_data" {
  name = "bp-ecg-prometheus-data"
}

resource "docker_volume" "grafana_data" {
  name = "bp-ecg-grafana-data"
}

# Write Prometheus configuration to disk so it can be volume-mounted into the container.
# This avoids docker_config resources which have provider version constraints.
resource "local_file" "prometheus_config" {
  filename        = "${local.module_path}/.rendered/prometheus.yml"
  file_permission = "0644"
  content         = <<-EOT
    global:
      scrape_interval: 15s
      evaluation_interval: 15s

    scrape_configs:
      # Trino coordinator metrics — Trino exposes JMX metrics at /v1/jmx/mbean, not /metrics.
      # The Prometheus endpoint requires a JMX exporter sidecar for proper scraping;
      # comment out until a JMX exporter is configured.
      # - job_name: trino
      #   static_configs:
      #     - targets:
      #         - trino:8080
      #   metrics_path: /metrics

      # bp_ecg_file_watcher custom metrics (port 8000)
      - job_name: bp_ecg_file_watcher
        static_configs:
          - targets:
              - host.docker.internal:8000
        metrics_path: /metrics

      # bp_ecg_raw_extractor custom metrics (port 8001)
      - job_name: bp_ecg_raw_extractor
        static_configs:
          - targets:
              - host.docker.internal:8001
        metrics_path: /metrics

      # MinIO server metrics
      - job_name: minio
        static_configs:
          - targets:
              - minio:9000
        metrics_path: /minio/v2/metrics/cluster

      # Prometheus self-scrape
      - job_name: prometheus
        static_configs:
          - targets:
              - localhost:9090
  EOT
}

# Write Grafana datasource provisioning file to disk for volume mounting.
resource "local_file" "grafana_datasource" {
  filename        = "${local.module_path}/.rendered/grafana-datasource.yml"
  file_permission = "0644"
  content         = <<-EOT
    apiVersion: 1

    datasources:
      - name: Prometheus
        type: prometheus
        access: proxy
        url: http://prometheus:9090
        isDefault: true
        editable: false
        jsonData:
          timeInterval: "15s"
  EOT
}

resource "docker_container" "prometheus" {
  name  = "bp-ecg-prometheus"
  image = docker_image.prometheus.image_id

  restart = "unless-stopped"

  networks_advanced {
    name    = docker_network.lakehouse.name
    aliases = ["prometheus"]
  }

  ports {
    internal = 9090
    external = var.prometheus_port
  }

  volumes {
    host_path      = local_file.prometheus_config.filename
    container_path = "/etc/prometheus/prometheus.yml"
    read_only      = true
  }

  volumes {
    volume_name    = docker_volume.prometheus_data.name
    container_path = "/prometheus"
  }

  command = [
    "--config.file=/etc/prometheus/prometheus.yml",
    "--storage.tsdb.path=/prometheus",
    "--storage.tsdb.retention.time=30d",
    "--web.console.libraries=/usr/share/prometheus/console_libraries",
    "--web.console.templates=/usr/share/prometheus/consoles",
    "--web.enable-lifecycle",
  ]

  healthcheck {
    test         = ["CMD-SHELL", "wget -q --spider http://localhost:9090/-/ready || exit 1"]
    interval     = "15s"
    timeout      = "5s"
    retries      = 5
    start_period = "30s"
  }

  depends_on = [local_file.prometheus_config]

  labels {
    label = "project"
    value = "bp-ecg"
  }
}

resource "docker_container" "grafana" {
  name  = "bp-ecg-grafana"
  image = docker_image.grafana.image_id

  restart = "unless-stopped"

  networks_advanced {
    name    = docker_network.lakehouse.name
    aliases = ["grafana"]
  }

  ports {
    internal = 3000
    external = var.grafana_port
  }

  env = [
    "GF_SECURITY_ADMIN_USER=admin",
    "GF_SECURITY_ADMIN_PASSWORD=admin",
    "GF_AUTH_ANONYMOUS_ENABLED=false",
    "GF_SERVER_ROOT_URL=http://localhost:${var.grafana_port}",
  ]

  volumes {
    host_path      = local_file.grafana_datasource.filename
    container_path = "/etc/grafana/provisioning/datasources/prometheus.yml"
    read_only      = true
  }

  volumes {
    volume_name    = docker_volume.grafana_data.name
    container_path = "/var/lib/grafana"
  }

  healthcheck {
    test         = ["CMD-SHELL", "curl -f http://localhost:3000/api/health || exit 1"]
    interval     = "15s"
    timeout      = "5s"
    retries      = 5
    start_period = "30s"
  }

  depends_on = [
    docker_container.prometheus,
    local_file.grafana_datasource,
  ]

  labels {
    label = "project"
    value = "bp-ecg"
  }
}
