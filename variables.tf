variable "node_count" {
  type = number
  default = 1
}

variable "region" {
  type = string
  default = "ams3"
}

variable "port" {
    type = number
    default = 25565
}

variable "envs" {
  type = map(string)
  default = {
    "MINECRAFT_MOTD": "HashiCraft"
    "RCON_ENABLED": "true"
    "RCON_PASSWORD": "password"
    "WORLD_BACKUP": "https://github.com/HashiCraft/digital-ocean-tide/releases/download/v0.0.0/world.tar.gz"
  }
}

variable "volume" {
    type = string
    default = "minecraftdata"
}

variable "mounts" {
  type = list(object({
    source = string
    destination = string
  }))
  default = [
    {
      source = "mods"
      destination = "/minecraft/mods"
    },
    
    {
      source = "world"
      destination = "/minecraft/world"
    },
    
    {
      source = "config"
      destination = "/minecraft/config"
    }
  ]
}