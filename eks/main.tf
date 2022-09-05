provider "aws" {
  region = "us-east-1"
}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

terraform {
  backend "s3" {
    bucket               = "terraform-remote-states"
    workspace_key_prefix = "environments"
    key                  = "eks"
    region               = "us-east-1"
  }
}


provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  load_config_file       = false
  version                = "~> 1.21"
}

data "aws_availability_zones" "available" {
}


locals {
  network_cidr          = lookup(var.network_cidr, terraform.workspace, null)
  private_subnet_cidrs  = lookup(var.private_subnet_cidrs, terraform.workspace, null)
  public_subnet_cidrs   = lookup(var.public_subnet_cidrs, terraform.workspace, null)
  cluster_name = lookup(var.cluster_name, terraform.workspace, null)
  instance_type = lookup(var.instance_type, terraform.workspace, null)
}


module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.47.0"

  name                 = "k8s-${local.environments}-vpc"
  cidr                 = local.network_cidr
  azs                  = data.aws_availability_zones.available.names
  private_subnets      = local.private_subnet_cidrs
  public_subnets       = local.public_subnet_cidrs
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "12.2.0"

  cluster_name    = "eks-${local.cluster_name}"
  cluster_version = "1.21"
  subnets         = module.vpc.private_subnets

  vpc_id = module.vpc.vpc_id

  node_groups = {
    first = {
      desired_capacity = 1
      max_capacity     = 3
      min_capacity     = 1

      instance_type = local.instance_type
    }
  }

  write_kubeconfig   = true
  config_output_path = "./"

  workers_additional_policies = [aws_iam_policy.worker_policy.arn]
}

provider "aws" {
  version = "~> 2.0"
  region  = "us-east-1" 
}

resource "aws_iam_policy" "worker_policy" {
  name        = "worker-policy-${local.cluster_name}"
  description = "Worker policy for the ALB Ingress"

  policy = file("iam-policy.json")
}

provider "helm" {
  version = "3.8.0"
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
    token                  = data.aws_eks_cluster_auth.cluster.token
    load_config_file       = false
  }
}


resource "helmfile_release_set" "frontend" {
	content = file("frontend/helmfile.yaml")
	kubeconfig        = pathexpand("./")
	environment       = local.cluster_name
	values = [
		<<EOF
{ "image": {"tag": "3.14" } }
EOF
	]
}
resource "helm_release" "ingress" {
  name       = "ingress"
  chart      = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  version    = "1.4.3"

  set {
    name  = "autoDiscoverAwsRegion"
    value = "true"
  }
  set {
    name  = "autoDiscoverAwsVpcID"
    value = "true"
  }
  set {
    name  = "clusterName"
    value = local.cluster_name
  }
}