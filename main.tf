terraform {
  required_providers {
    # Kubernetes provider
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    # Helm provider
    helm = {
      source = "hashicorp/helm"
    }
  }
}

# Path to config file for the Kubernetes provider as variable
variable "kubeconfig" {
  type = string
  # Load the kubeconfig from your home directory (default location for Docker Desktop Kubernetes)
  default = "~/.kube/config"
}

# Kubernetes provider configuration
provider "kubernetes" {
  config_path = var.kubeconfig
}

# Helm provider configuration
provider "helm" {
  # Local Kubernetes cluster from Docker Desktop
  kubernetes {
    # Load the kubeconfig from your home directory
    config_path = var.kubeconfig
  }
}

###
# Create a new Kubernetes namespace for the application deployment
###
resource "kubernetes_namespace" "kubernetes_dashboard" {
  metadata {
    name = "kubernetes-dashboard"
  }
}

###
# Install the Kubernetes Dashboard using the Helm provider
###
resource "helm_release" "kubernetes_dashboard" {
  # Name of the release in the cluster
  name = "kubernetes-dashboard"

  # Name of the chart to install
  repository = "https://kubernetes.github.io/dashboard/"

  # Version of the chart to use
  chart = "kubernetes-dashboard"

  # Wait for the Kubernetes namespace to be created
  depends_on = [kubernetes_namespace.kubernetes_dashboard]

  # Set the namespace to install the release into
  namespace = kubernetes_namespace.kubernetes_dashboard.metadata[0].name

  # Set service type to LoadBalancer
  set {
    name  = "service.type"
    value = "LoadBalancer"
  }

  # Set service external port to 9080
  set {
    name  = "service.externalPort"
    value = "9080"
  }

  # Set protocol to HTTP (not HTTPS)
  set {
    name  = "protocolHttp"
    value = "true"
  }

  # Enable insecure login (no authentication)
  set {
    name  = "enableInsecureLogin"
    value = "true"
  }

  # Enable cluster read only role (no write access) for the dashboard user
  set {
    name  = "rbac.clusterReadOnlyRole"
    value = "true"
  }

  # Enable metrics scraper (required for the CPU and memory usage graphs)
  set {
    name  = "metricsScraper.enabled"
    value = "true"
  }

  # Wait for the release to be deployed
  wait = true
}

###
# Install the Metrics Server using the Helm provider
###
resource "helm_release" "metrics_server" {
  # Name of the release in the cluster
  name = "metrics-server"

  # Name of the chart to install
  repository = "https://kubernetes-sigs.github.io/metrics-server/"

  # Version of the chart to use
  chart = "metrics-server"

  # Wait for the Kubernetes Dashboard and Kubernetes namespace to be created
  depends_on = [helm_release.kubernetes_dashboard, kubernetes_namespace.kubernetes_dashboard]

  # Set the namespace to install the release into
  namespace = kubernetes_namespace.kubernetes_dashboard.metadata[0].name

  # Recent updates to the Metrics Server do not work with self-signed certificates by default.
  # Since Docker For Desktop uses such certificates, you’ll need to allow insecure TLS
  set {
    name  = "args"
    value = "{--kubelet-insecure-tls=true}"
  }

  # Wait for the release to be deployed
  wait = true
}

# Output metadata of the Kubernetes Dashboard release
output "kubernetes_dashboard_service_metadata" {
  value = helm_release.kubernetes_dashboard.metadata
}

# Output metadata of the Metrics Server release
output "metrics_server_service_metadata" {
  value = helm_release.metrics_server.metadata
}

# Output the URL of the Kubernetes Dashboard
output "kubernetes_dashboard_url" {
  value = "http://localhost:9080"
}
