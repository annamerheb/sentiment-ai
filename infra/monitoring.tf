resource "docker_container" "prometheus" {
  name    = "prometheus"
  image   = docker_image.prometheus.image_id
  restart = "unless-stopped"

  networks_advanced {
    name = "cicd-network"
  }

  ports {
    internal = 9090
    external = 9090
  }

  command = [
    "--config.file=/etc/prometheus/prometheus.yml",
    "--storage.tsdb.retention.time=15d"
  ]

  volumes {
    volume_name    = "prometheus_data"
    container_path = "/prometheus"
  }

  volumes {
    host_path      = "/var/jenkins_home/workspace/sentiment-ai-pipeline/monitoring/prometheus.yml"
    container_path = "/etc/prometheus/prometheus.yml"
    read_only      = true
  }

  volumes {
    host_path      = "/var/jenkins_home/workspace/sentiment-ai-pipeline/monitoring/alerts.yml"
    container_path = "/etc/prometheus/alerts.yml"
    read_only      = true
  }
}