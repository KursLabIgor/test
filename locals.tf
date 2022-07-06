
locals {
  infra_subnets_tag = {
    Tier = "infra"
  }
  public_subnet_tags = {
    Tier = "public"
  }
  private_subnet_tags = {
    Tier = "private"
  }
 env_prefix = "${var.env}-${terraform.workspace}"
 name_prefix = "${var.env}-${var.region_name}-${terraform.workspace}"
 name = {
    Name = "${local.name_prefix}"
  }
 vpc_tag_extra = {
   Environment = "${var.env}-${terraform.workspace}"
 }
  common_tags = {
    Owner       = "devops"
    Environment = "${var.env}"
    Terraform = "true"
    Workspace = "${terraform.workspace}"
    Region    = "${var.region}"
    Application = "${var.app}"
  }
}

