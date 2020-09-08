resource "digitalocean_kubernetes_cluster" "minecraft" {
  name    = "minecraft"
  region  = "ams3"
  # Grab the latest version slug from `doctl kubernetes options versions`
  version = "1.18.8-do.0"

  node_pool {
    name       = "worker-pool"
    size       = "s-2vcpu-2gb"
    node_count = 1
  }
}

provider "kubernetes" {
  load_config_file = false
  host  = digitalocean_kubernetes_cluster.minecraft.endpoint
  token = digitalocean_kubernetes_cluster.minecraft.kube_config[0].token
  cluster_ca_certificate = base64decode(
    digitalocean_kubernetes_cluster.minecraft.kube_config[0].cluster_ca_certificate
  )
}

resource "kubernetes_deployment" "minecraft" {
  metadata {
    name = "minecraft"
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
          image = "hashicraft/minecraft:v1.16.2"
          name  = "minecraft"

          port {
            container_port = 25565
            name = "minecraft"
          }

          env {
            name = "MINECRAFT_MOTD"
            value = "HashiCraft"
          }
  
          env {
            name = "RCON_PASSWORD"
            value = "password"
          }
  
          env {
            name = "RCON_ENABLED"
            value = "true"
          }

          # Install default Mods and World
          env {
            name = "WORLD_BACKUP"
            value = "https://github.com/HashiCraft/digital-ocean-tide/releases/download/v0.0.0/world.tar.gz"
          }

          volume_mount {
            mount_path = "/minecraft/mods"
            name = "minecraftdata"
            sub_path = "mods"
          }
          
          volume_mount {
            mount_path = "/minecraft/world"
            name = "minecraftdata"
            sub_path = "world"
          }
          
          volume_mount {
            mount_path = "/minecraft/config"
            name = "minecraftdata"
            sub_path = "config"
          }
        }

        volume {
          name = "minecraftdata"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.minecraftdata.metadata.0.name
          }
        }
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "minecraftdata" {
  metadata {
    name = "minecraftdata"
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

resource "kubernetes_service" "minecraft" {
  metadata {
    name = "minecraft"
  }
  spec {
    selector = {
      app = kubernetes_deployment.minecraft.metadata.0.labels.app
    }
    
    port {
      port        = 25565
      target_port = 25565
    }

    type = "LoadBalancer"
  }
}

output "k8s_config" {
  value = digitalocean_kubernetes_cluster.minecraft.kube_config.0.raw_config
}