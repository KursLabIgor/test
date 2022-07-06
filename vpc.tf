data "aws_availability_zones" "azs" {
  state = "available"
}
resource "aws_eip" "nat_ip" {
  count = 1
  vpc = true
}

module "vpc" {
  source              = "terraform-aws-modules/vpc/aws"

  name                = "${local.env_prefix}-vpc"
  cidr                = var.vpc_cidr

  azs                 = data.aws_availability_zones.azs.names
  private_subnets     = var.private_subnets
  public_subnets      = var.public_subnets

  enable_nat_gateway  = true
  single_nat_gateway  = true
  reuse_nat_ips       = true
  external_nat_ip_ids = "${aws_eip.nat_ip.*.id}"
  tags                = local.common_tags
  public_subnet_tags  = local.public_subnet_tags
  private_subnet_tags = local.private_subnet_tags
}