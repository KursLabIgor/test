resource "aws_ecr_repository" "ecr" {
  name                 = "${local.name_prefix}-ecr"
  image_tag_mutability = "MUTABLE"
  tags = local.common_tags
}
resource "aws_ecs_cluster" "ecs_cluster" {
  name                  = "${local.name_prefix}-cluster"
  tags                  = "${local.common_tags}"
}
resource "aws_ecs_cluster_capacity_providers" "ecs_capacity_provider" {
  cluster_name          = aws_ecs_cluster.ecs_cluster.name

  capacity_providers    = ["FARGATE_SPOT"]

  default_capacity_provider_strategy {
    base                = 1
    weight              = 100
    capacity_provider   = "FARGATE_SPOT"
  }
}

module "alb" {
  source                = "umotif-public/alb/aws"
  version               = "~> 2.0"

  name_prefix           = "alb-example"
  load_balancer_type    = "application"
  internal              = false
  vpc_id                = module.vpc.vpc_id
  subnets               = module.vpc.public_subnets
}

resource "aws_lb_listener" "alb_80" {
  load_balancer_arn     = module.alb.arn
  port                  = "80"
  protocol              = "HTTP"

  default_action {
    type                = "forward"
    target_group_arn    = module.fargate.target_group_arn[0]
  }
}

#####
# Security Group Config
#####
resource "aws_security_group_rule" "alb_ingress_80" {
  security_group_id    = module.alb.security_group_id
  type                 = "ingress"
  protocol             = "tcp"
  from_port            = 80
  to_port              = 80
  cidr_blocks          = ["0.0.0.0/0"]
  ipv6_cidr_blocks     = ["::/0"]
}

resource "aws_security_group_rule" "task_ingress_80" {
  security_group_id        = module.fargate.service_sg_id
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = 80
  to_port                  = 80
  source_security_group_id = module.alb.security_group_id
}

module "fargate" {
  source                          = "umotif-public/ecs-fargate/aws"
  version                         = "~> 6.5.0"

  name_prefix                     = "${local.name_prefix}-service"
  vpc_id                          = module.vpc.vpc_id
  private_subnet_ids              = module.vpc.private_subnets

  cluster_id                      = aws_ecs_cluster.ecs_cluster.id
  task_container_image            = "${aws_ecr_repository.ecr.repository_url}:latest"
  task_definition_cpu             = 256
  task_definition_memory          = 512

  task_container_port             = 80
  task_container_assign_public_ip = false

  target_groups                   = [
    {
      target_group_name           = "${local.name_prefix}-tg"
      container_port              = 80
      deregistration_delay        = 60
    }
  ]

  health_check                     = {
    port                           = "traffic-port"
    path                           = "/"
  }
  capacity_provider_strategy = [
    {
      capacity_provider = "FARGATE_SPOT",
      weight            = 100
    }]
  tags                             = local.common_tags
  depends_on                       = [
    module.alb
  ]
}
module "scaling" {
  source       = "./modules/scaling"
  prefix_name  = local.name_prefix
  cluster = aws_ecs_cluster.ecs_cluster.name
  service_name = "${local.name_prefix}-service"
  alb_suffix = module.alb.arn_suffix
  autoscale    = {
          scale_up_comparison_operator   = "GreaterThanThreshold"
          scale_up_threshold             = 10
          scale_down_comparison_operator = "LessThanThreshold"
          scale_down_threshold           = 5
          evaluation_periods             = 2
          datapoints_to_alarm            = 2
          metric_name                    = "RequestCount"
          statistic                      = "Sum"
          adjustment_type                = "ChangeInCapacity"
          cooldown                       = 60
          scale_down_adjustment          = -1
          scale_up_adjustment            = 3
  }
  depends_on = [ module.fargate ]
}