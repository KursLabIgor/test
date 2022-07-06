variable "region" {
}
variable "env" {}
variable "app" {}
variable "vpc_cidr" {}
variable "private_subnets" {
  description = "ip cidr range"
}
variable "public_subnets" {
  description = "ip cidr range"
}
variable "region_name" {
  description = "alias name for region"
}
variable "ecs_cluster_parameters" {
  type = map
}
variable "circleci_org_name" {
  default = "KursLabIgor"
}