terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "digitalocean" {}

resource "digitalocean_kubernetes_cluster" "minecraft" {
  name    = var.name
  region  = var.region
  version = "1.28.2-do.0"

  node_pool {
    name       = "worker-pool"
    size       = "s-2vcpu-2gb"
    node_count = var.node_count
  }
}

provider "kubernetes" {
  host                   = digitalocean_kubernetes_cluster.minecraft.endpoint
  token                  = digitalocean_kubernetes_cluster.minecraft.kube_config[0].token
  cluster_ca_certificate = base64decode(digitalocean_kubernetes_cluster.minecraft.kube_config[0].cluster_ca_certificate)
}

resource "kubernetes_deployment" "minecraft" {
  metadata {
    name   = "minecraft"
    labels = {
      app = "minecraft"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "minecraft"
      }
    }

    template {
      metadata {
        labels = {
          app = "minecraft"
        }
      }

      spec {
        container {
          image             = var.image
          name              = "minecraft"
          image_pull_policy = "Always"

          port {
            container_port = var.port
            name           = "minecraft"
          }

          dynamic "env" {
            for_each = var.envs

            content {
              name  = env.key
              value = env.value
            }
          }

          dynamic "volume_mount" {
            for_each = var.mounts

            content {
              name       = kubernetes_persistent_volume_claim.minecraftdata.metadata[0].name
              sub_path   = volume_mount.value.source
              mount_path = volume_mount.value.destination
            }
          }
        }

        volume {
          name = kubernetes_persistent_volume_claim.minecraftdata.metadata[0].name

          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.minecraftdata.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "minecraft" {
  metadata {
    name = "minecraft"
  }

  spec {
    selector = {
      app = "minecraft"
    }

    port {
      port        = var.port
      target_port = var.port
    }

    type = "LoadBalancer"
  }
}

resource "kubernetes_persistent_volume_claim" "minecraftdata" {
  metadata {
    name = var.volume
  }

  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "10Gi"
      }
    }
  }
}

output "k8s_config" {
  value = digitalocean_kubernetes_cluster.minecraft.kube_config[0].raw_config
  sensitive = true
}

output "lb_address" {
  value = kubernetes_service.minecraft.status[0].load_balancer[0].ingress[0].ip
}