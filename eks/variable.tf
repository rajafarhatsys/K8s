variable "network_cidr" {
  type    = list(string)
  default = {
    staging    = "10.0.0.0/16"
    qa         = "10.1.0.0/16"
    production = "10.2.0.0/16"
  }
}

variable "private_subnet_cidrs" {
  type = list(string)
  default = {
    staging    = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]
    qa         = ["10.1.0.0/24", "10.1.1.0/24", "10.1.2.0/24"]
    production = ["10.2.0.0/24", "10.2.1.0/24", "10.2.2.0/24"]
  }
}

variable "public_subnet_cidrs" {
  type = list(string)
  default = {
    staging    = ["10.0.3.0/24", "10.0.4.0/24", "10.0.5.0/24"]
    qa         = ["10.1.3.0/24", "10.1.4.0/24", "10.1.5.0/24"]
    production = ["10.2.3.0/24", "10.2.4.0/24", "10.2.5.0/24"]
  }
}
variable "environments" {
  type = string
  default = {
    staging    = "staging"
    qa         = "qa"
    production = "production"
  }
}


variable "instance_type" {
  type = string
  default = {
    staging    = "t2.medium"
    qa         = "m5.xlarge"
    production = "m5.4xlarge"
  }
}
