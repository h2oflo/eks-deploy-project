locals {
  name = var.cluster_name
  tags = {
    Environment = "prod"
    Terraform   = "true"
  }
}

data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.us_east_1
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.36.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  enable_cluster_creator_admin_permissions = true
  # setting to true for testing purposed. Would otherwise be locked down
  cluster_endpoint_public_access = true

  cluster_addons = {
    coredns                = {}
    eks-pod-identity-agent = {}
    kube-proxy             = {}
    vpc-cni                = {}
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    karpenter = {
      ami_type       = "BOTTLEROCKET_x86_64"
      instance_types = ["m5.large"]

      min_size     = 2
      max_size     = 3
      desired_size = 2

      labels = {
        # Used to ensure Karpenter runs on nodes that it does not manage
        "karpenter.sh/controller" = "true"
      }
    }
  }

  node_security_group_tags = merge(local.tags, {
    # NOTE - if creating multiple security groups with this module, only tag the
    # security group that Karpenter should utilize with the following tag
    # (i.e. - at most, only one security group should have this tag in your account)
    "karpenter.sh/discovery" = "eks-learning-terraform"
  })
}

module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "20.36.0"

  cluster_name          = module.eks.cluster_name
  enable_v1_permissions = true

  # Name needs to match role name passed to the EC2NodeClass
  node_iam_role_use_name_prefix   = false
  node_iam_role_name              = "eks-learning-terraform"
  create_pod_identity_association = true

  # The EC2NodeClass in karpenter-nodepool references this profile by name;
  # without it Karpenter cannot launch any nodes
  create_instance_profile = true

  # Used to attach additional IAM policies to the Karpenter node IAM role
  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }
}

resource "helm_release" "karpenter" {
  namespace           = "kube-system"
  name                = "karpenter"
  repository          = "oci://public.ecr.aws/karpenter"
  repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  repository_password = data.aws_ecrpublic_authorization_token.token.password
  chart               = "karpenter"
  version             = "1.9.0"
  wait                = false

  values = [
    <<-EOT
    nodeSelector:
      karpenter.sh/controller: 'true'
    dnsPolicy: Default
    settings:
      clusterName: ${module.eks.cluster_name}
      clusterEndpoint: ${module.eks.cluster_endpoint}
      interruptionQueue: ${module.karpenter.queue_name}
    webhook:
      enabled: false
    EOT
  ]
}

# Karpenter v1 CRDs must exist before the NodePool/EC2NodeClass resources
# can be applied (the chart installs CRDs in a pre-install hook, which
# helm_release with wait=false does not wait for)
data "http" "karpenter_crds" {
  for_each = toset(var.karpenter_crds_urls)

  url = each.value
}

resource "kubectl_manifest" "karpenter_crds" {
  for_each = data.http.karpenter_crds

  yaml_body          = each.value.response_body
  override_namespace = ""
  apply_only         = true # CRDs are managed by the chart upgrade path; don't fight it

  depends_on = [helm_release.karpenter]
}

# NodePool + EC2NodeClass rendered from karpenter-nodepool.yaml.tftpl, so
# cluster name, VPC name and instance profile always match the Terraform
# config. Two documents in one template -> indexed by metadata.name.
resource "kubectl_manifest" "karpenter_nodepool" {
  for_each = { for doc in yamldecode(templatefile("${path.module}/karpenter-nodepool.yaml.tftpl", {
    cluster_name     = var.cluster_name
    vpc_name         = var.vpc_name
    instance_profile = module.karpenter.instance_profile_name
  })) : try(doc.metadata.name, "unknown") => doc }

  yaml_body          = yamlencode(each.value)
  override_namespace = ""

  depends_on = [
    helm_release.karpenter,
    kubectl_manifest.karpenter_crds,
  ]
}