
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.30.0"
    }
  }
  backend "s3" {
    bucket         = "poc-s3-backend"
    key            = "dev/ecs-service.tfstate"
    region         = "us-east-2"
    dynamodb_table = "poc-s3-backend"
    role_arn       = "arn:aws:iam::773801579928:role/PocS3BackendRole"
  }
}

locals {
  task_container_name = "app"
}

provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

# data "aws_ecs_cluster" "main" {
#   cluster_name = var.ecs_cluster_name
# }

# data "aws_lb" "main" {
#   name = "${var.project_name}-${var.env}-alb"
# }

# data "aws_service_discovery_http_namespace" "main" {
#   name = "poc.local"
# }

data "aws_codestarconnections_connection" "main" {
  name = "Github Connection"
}

# data "aws_s3_bucket" "fe_s3" {
#   bucket = var.webapp_s3_bucker
# }

data "aws_iam_role" "codebuild_iam" {
  name = "codebuild-${var.project_name}-${var.env}-service-role"
}

data "aws_iam_role" "codepipeline_iam" {
  name = "codepipeline-${var.project_name}-${var.env}-service-role"
}

data "aws_iam_role" "lambda_iam" {
  name = "lambda-${var.project_name}-${var.env}-service-role"
}

resource "aws_s3_bucket" "code_pipeline" {
  bucket        = "codepipeline-${var.project_name}-${var.env}"
  force_destroy = true

  tags = {
    Name        = "codepipeline for ecs"
    Environment = var.env
  }
}

# module "webapp-ci-cd" {
#   source = "./ci-cd-simple"
#   app_name = "poc-fe"
#   env = var.env
#   aws_region = var.aws_region
#   codebuild_config = {
#     buildspec              = "deployment/buildspec.yml"
#     codebuild_service_role = data.aws_iam_role.codebuild_iam.arn
#     codebuild_env = [
#       {
#         name  = "API_BASE_URL"
#         value = "https://api.bsm-poc.tannguyenit.dev"
#       },
#       {
#         name  = "S3_BUCKET"
#         value = var.webapp_s3_bucker
#       },
#       {
#         name  = "CLOUDFRONT_DISTRIBUTION_ID"
#         value = var.webapp_cloudfront_id
#       }
#     ]
#   }
#   codepipeline = {
#     connection_arn             = data.aws_codestarconnections_connection.main.arn
#     codepipeline_service_role  = data.aws_iam_role.codepipeline_iam.arn
#     s3_artifact_store_location = aws_s3_bucket.code_pipeline.id
#     build_stage_name_alias = "Build_and_clear_cache_cloudfront"
#     # raw value
#     repository_id     = "tannguyenbsm/poc-frontend"
#     repository_branch = "dev"
#   }
# }

module "lambda-ci-cd" {
  source = "./ci-cd-simple"
  app_name = "poc-lambda-function"
  env = var.env
  aws_region = var.aws_region
  codebuild_config = {
    buildspec              = "deployment/buildspec.yml"
    codebuild_service_role = data.aws_iam_role.codebuild_iam.arn
    codebuild_env = [
      {
        name  = "ROLE_ARN"
        value = data.aws_iam_role.lambda_iam.arn
      },
      {
        name  = "S3_ORIGINAL_IMAGE_BUCKET"
        value = "bucket-bsm-poc-dev"
      },
      {
        name  = "S3_TRANSFORMED_IMAGE_BUCKET"
        value = "bucket-bsm-poc-dev"
      },
      {
        name  = "TRANSFORMED_IMAGE_CACHE_TTL"
        value = "86400"
      },
      {
        name  = "SECRET_KEY"
        value = "SECRET_KEY"
      },
      {
        name  = "MAX_IMAGE_SIZE"
        value = "10240"
      }
    ]
  }
  codepipeline = {
    connection_arn             = data.aws_codestarconnections_connection.main.arn
    codepipeline_service_role  = data.aws_iam_role.codepipeline_iam.arn
    s3_artifact_store_location = aws_s3_bucket.code_pipeline.id
    build_stage_name_alias = "Build_and_deploy_lambd_function"
    # raw value
    repository_id     = "tannguyenbsm/poc-lambda"
    repository_branch = "dev"
  }
}

# module "gateway-service" {
#   source       = "./backend"
#   env          = var.env
#   aws_region   = var.aws_region
#   vpc_id       = var.vpc_id
#   project_name = var.project_name
#   codebuild_config = {
#     buildspec              = "deployment/buildspec.yml"
#     codebuild_service_role = data.aws_iam_role.codebuild_iam.arn
#     codebuild_env = [
#       {
#         name  = "USER_SERVICE_API_BASE"
#         value = "user-svc.poc.local"
#       }
#     ]
#   }
#   ecs = {
#     # Data value
#     cluster_arn                    = data.aws_ecs_cluster.main.arn
#     cluster_name                   = data.aws_ecs_cluster.main.cluster_name
#     service_discovery_namespace_id = data.aws_service_discovery_http_namespace.main.arn
#     # Variable value
#     task_execution_role_arn = var.ecs_task_execution_role_arn
#     task_role_arn           = var.ecs_task_role_arn
#     task_security_group_id  = var.ecs_task_security_group_id
#     vpc_subnet_ids          = var.vpc_subnet_ids
#     alb_target_group_arn    = var.alb_target_group_arn
#     # raw value
#     service_name   = "gateway-svc"
#     app_port       = 80
#     fargate_cpu    = 256
#     fargate_memory = 512
#     container = {
#       name = "app"
#       health_check = {
#         command = [
#           "CMD-SHELL",
#           "curl -f http://localhost/health || exit 1"
#         ]
#         interval    = 30
#         retries     = 2
#         startPeriod = 0
#       }
#     }
#   }

#   codepipeline = {
#     connection_arn             = data.aws_codestarconnections_connection.main.arn
#     codepipeline_service_role  = data.aws_iam_role.codepipeline_iam.arn
#     s3_artifact_store_location = aws_s3_bucket.code_pipeline.id
#     # raw value
#     repository_id     = "tannguyenbsm/poc-api-gw"
#     repository_branch = "dev"
#   }
#   autoscaling = {
#     max_capacity = 3
#     min_capacity = 1
#   }
# }

# module "user-service-event" {
#   source = "../../../modules/eventRule"
#   schedule_name = "send-mail-to-lender"
#   schedule_desc = "send email to lender if not have logo"
#   schedule_expression = "rate(12 hours)"
#   ecs_command_overrides = ["/usr/local/bin/node", "cronjob.js"]
#   ecs_cluster_arn = data.aws_ecs_cluster.main.arn
#   execution_role_arn = var.ecs_event_execution_role_arn
#   ecs_service_name = module.user-service.service_name
#   ecs_container_name = local.task_container_name
#   vpc_subnets = var.vpc_subnet_ids
#   vpc_security_groups = [var.ecs_task_security_group_id]
#   ecs_task_definition_arn = module.user-service.task_definition_arn_without_revision
# }

# module "user-service" {
#   source       = "./backend"
#   env          = var.env
#   aws_region   = var.aws_region
#   vpc_id       = var.vpc_id
#   project_name = var.project_name
#   codebuild_config = {
#     buildspec              = "deployment/buildspec.yml"
#     codebuild_service_role = data.aws_iam_role.codebuild_iam.arn
#     codebuild_env          = []
#   }
#   ecs = {
#     # Data value
#     cluster_arn                    = data.aws_ecs_cluster.main.arn
#     cluster_name                   = data.aws_ecs_cluster.main.cluster_name
#     service_discovery_namespace_id = data.aws_service_discovery_http_namespace.main.arn
#     # Variable value
#     task_execution_role_arn = var.ecs_task_execution_role_arn
#     task_role_arn           = var.ecs_task_role_arn
#     task_security_group_id  = var.ecs_task_security_group_id
#     vpc_subnet_ids          = var.vpc_subnet_ids
#     alb_target_group_arn    = ""
#     # raw value
#     service_name   = "user-svc"
#     app_port       = 80
#     fargate_cpu    = 256
#     fargate_memory = 512
#     container = {
#       name = "app"
#       health_check = {
#         command = [
#           "CMD-SHELL",
#           "curl -f http://localhost/health || exit 1"
#         ]
#         interval    = 30
#         retries     = 2
#         startPeriod = 0
#       }
#     }
#   }

#   codepipeline = {
#     connection_arn             = data.aws_codestarconnections_connection.main.arn
#     codepipeline_service_role  = data.aws_iam_role.codepipeline_iam.arn
#     s3_artifact_store_location = aws_s3_bucket.code_pipeline.id
#     # raw value
#     repository_id     = "tannguyenbsm/poc-user-svc"
#     repository_branch = "dev"
#   }
#   autoscaling = {
#     max_capacity = 3
#     min_capacity = 1
#   }
# }
