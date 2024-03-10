provider "aws" {
  alias = "workflows"

  region = "us-west-2"

  default_tags {
    tags = {
      (module.aspect_workflows.cost_allocation_tag) = module.aspect_workflows.cost_allocation_tag_value
    }
  }
}

data "aws_ami" "runner_amd64_ami" {
  # Aspect's AWS account 213396452403 provides public Aspect Workflows images for getting started
  # during the trial period. We recommend that all Workflows users build their own AMIs and keep
  # up-to date with patches. See https://docs.aspect.build/workflows/install/packer for more info
  # and/or https://github.com/aspect-build/workflows-images for example packer scripts and BUILD
  # targets for building AMIs for Workflows.
  owners      = ["213396452403"]
  most_recent = true
  filter {
    name   = "name"
    values = ["aspect-workflows-al2023-gcc-amd64-*"]
  }
}

data "aws_ami" "runner_arm64_ami" {
  # Aspect's AWS account 213396452403 provides public Aspect Workflows images for getting started
  # during the trial period. We recommend that all Workflows users build their own AMIs and keep
  # up-to date with patches. See https://docs.aspect.build/workflows/install/packer for more info
  # and/or https://github.com/aspect-build/workflows-images for example packer scripts and BUILD
  # targets for building AMIs for Workflows.
  owners      = ["213396452403"]
  most_recent = true
  filter {
    name   = "name"
    values = ["aspect-workflows-al2023-gcc-arm64-*"]
  }
}

module "remote_cache_dns" {
  source  = "terraform-aws-modules/route53/aws//modules/zones"
  version = "2.10.2"

  zones = {
    "rules-ts-remote-cache.aspect.build" = {
      domain_name = "rules-ts-remote-cache.aspect.build"
      comment     = "rules-ts-remote-cache.aspect.build"
      tags = {
        Name = "rules-ts-remote-cache.aspect.build"
      }
    }
  }
}

module "aspect_workflows" {
  providers = {
    aws = aws.workflows
  }

  # Aspect Workflows terraform module
  source = "https://s3.us-east-2.amazonaws.com/static.aspect.build/aspect/5.9.22/terraform-aws-aspect-workflows.zip"

  # Non-terraform Aspect Workflows release artifacts are pulled from the region specific
  # aspect-artifacts bucket during apply. Aspect will grant your AWS account access to this bucket
  # during the trial setup. The aspect-artifacts bucket used must in the same region as the
  # deployment.
  aspect_artifacts_bucket = "aspect-artifacts-us-west-2"

  # Name of the deployment
  customer_id = "aspect-build/rules_ts"

  # VPC properties
  vpc_id             = module.vpc.vpc_id
  vpc_subnets        = module.vpc.private_subnets
  vpc_subnets_public = module.vpc.public_subnets

  support = {
    # PagerDuty key for this deployment
    pagerduty_integration_key = "39eddf9c91be4100d0a709f2d04bc4bd"
    # Whether or not to allow SSM access to runners
    enable_ssm_access = true
  }

  # Remote cache properties
  remote_cache = {
    # The remote cache in this deployment is tuned for cost. In a deployment that requires a large
    # high-performance cache we recommend 3+ shards and i4i instances. The remote cache uses NVMe
    # storage under the hood so the instance type selected must have NVMe storage available. The
    # total size of the remote cache will be size of the NVMe drives available on the selected
    # instance type multiplied by the number of cache shards.
    cache_shards = 1
    frontend = {
      max_scaling = 5
      min_scaling = 1
    }
    storage_instance_type = "c5ad.large"
  }

  external_remote_cache = {
    public_hosted_zone_id = module.remote_cache_dns.route53_zone_zone_id["rules-ts-remote-cache.aspect.build"]
    cache_shards          = 1
    frontend = {
      max_scaling = 5
      min_scaling = 1
    }
    storage_instance_type = "c5ad.large"
  }

  # Delivery properties
  delivery_enabled = true

  # CI properties
  hosts = ["gha"]

  # Warming set definitions
  warming_sets = {
    default = {}
  }

  # Resource types for use by runner groups. Aspect recommends instance types that have nvme drives
  # for large Bazel workflows. See https://aws.amazon.com/ec2/instance-types/ for list of instance
  # types available on AWS.
  resource_types = {
    "default" = {
      instance_types = ["c5ad.xlarge"]
      image_id       = data.aws_ami.runner_amd64_ami.id
    }
    "small-amd64" = {
      instance_types      = ["t3a.small"]
      image_id            = data.aws_ami.runner_amd64_ami.id
      root_volume_size_gb = 32
    }
    "small-arm64" = {
      instance_types      = ["t4g.small"]
      image_id            = data.aws_ami.runner_arm64_ami.id
      root_volume_size_gb = 32
    }
    "nano" = {
      instance_types      = ["t4g.nano"]
      image_id            = data.aws_ami.runner_arm64_ami.id
      root_volume_size_gb = 16
    }
  }

  # GitHub Actions runner group definitions
  gha_runner_groups = {
    # The default runner group is use for the main build & test workflows.
    default = {
      agent_idle_timeout_min = 1
      gh_repo                = "aspect-build/rules_ts"
      # Determine the workflow ID with:
      # gh api -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" /repos/aspect-build/rules_ts/actions/workflows
      # https://docs.github.com/en/rest/actions/workflows?apiVersion=2022-11-28#list-repository-workflows
      gha_workflow_ids          = ["66360195"] # Aspect Workflows
      max_runners               = 5
      min_runners               = 0
      queue                     = "aspect-default"
      resource_type             = "default"
      scaling_polling_frequency = 1 # check for queued jobs every 60s
      warming                   = true
    }
    small-amd64 = {
      agent_idle_timeout_min = 10
      gh_repo                = "aspect-build/rules_ts"
      # Determine the workflow ID with:
      # gh api -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" /repos/aspect-build/rules_ts/actions/workflows
      # https://docs.github.com/en/rest/actions/workflows?apiVersion=2022-11-28#list-repository-workflows
      gha_workflow_ids          = ["66360195"] # Aspect Workflows
      max_runners               = 5
      min_runners               = 0
      queue                     = "aspect-small-amd64"
      resource_type             = "small-amd64"
      scaling_polling_frequency = 1     # check for queued jobs every 60s
      warming                   = false # don't warm for faster bootstrap; these runners won't be running large builds
    }
    small-arm64 = {
      agent_idle_timeout_min = 10
      gh_repo                = "aspect-build/rules_ts"
      # Determine the workflow ID with:
      # gh api -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" /repos/aspect-build/rules_ts/actions/workflows
      # https://docs.github.com/en/rest/actions/workflows?apiVersion=2022-11-28#list-repository-workflows
      gha_workflow_ids          = ["66360195"] # Aspect Workflows
      max_runners               = 5
      min_runners               = 0
      queue                     = "aspect-small-arm64"
      resource_type             = "small-arm64"
      scaling_polling_frequency = 1     # check for queued jobs every 60s
      warming                   = false # don't warm for faster bootstrap; these runners won't be running large builds
    }
    nano = {
      agent_idle_timeout_min = 60 * 12
      gh_repo                = "aspect-build/rules_ts"
      # Determine the workflow ID with:
      # gh api -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" /repos/aspect-build/rules_ts/actions/workflows
      # https://docs.github.com/en/rest/actions/workflows?apiVersion=2022-11-28#list-repository-workflows
      gha_workflow_ids          = ["66360195"] # Aspect Workflows
      max_runners               = 5
      min_runners               = 0
      queue                     = "aspect-nano"
      resource_type             = "nano"
      scaling_polling_frequency = 1     # check for queued jobs every 60s
      warming                   = false # don't warm for faster bootstrap; these runners won't be running large builds
    }
    # The warming runner group is used for the periodic warming job that creates
    # warming archives for use by other runner groups.
    warming = {
      agent_idle_timeout_min = 1
      gh_repo                = "aspect-build/rules_ts"
      # Determine the workflow ID with:
      # gh api -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" /repos/aspect-build/rules_ts/actions/workflows
      # https://docs.github.com/en/rest/actions/workflows?apiVersion=2022-11-28#list-repository-workflows
      gha_workflow_ids = ["66594869"] # Aspect Workflows Warming
      max_runners      = 1
      min_runners      = 0
      policies         = { warming_manage : module.aspect_workflows.warming_management_policies["default"].arn }
      queue            = "aspect-warming"
      resource_type    = "default"
    }
  }
}

module "managed_grafana" {
  source = "./managed-grafana"
}

module "aspect_workflows_grafana_dashboards" {
  # Aspect Workflows grafana dashboard nested terraform module
  source = "https://s3.us-east-2.amazonaws.com/static.aspect.build/aspect/5.9.22/terraform-aws-aspect-workflows.zip//monitoring/dashboards"

  grafana_auth                = module.managed_grafana.grafana_admin_api_key
  grafana_url                 = module.managed_grafana.grafana_endpoint
  managed_prometheus_endpoint = module.aspect_workflows.managed_prometheus_endpoint
}
