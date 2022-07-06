region                            = "eu-west-1"
app                               = "web"
region_name                       = "euw1"
env                               = "dev"
ecs_cluster_parameters            = {
  FARGATE_BASE = 0
  FARGATE_WEIGHT = 0
  FARGATE_SPOT_BASE = 1
  FARGATE_SPOT_WEIGHT = 1
}
