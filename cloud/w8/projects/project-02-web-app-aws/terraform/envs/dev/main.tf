module "vpc" {
  source = "../../modules/vpc"

  project_name            = "${var.project_name}-${var.environment}"
  vpc_cidr                = var.vpc_cidr
  public_subnet_cidrs     = var.public_subnet_cidrs
  private_subnet_cidrs    = var.private_subnet_cidrs
  availability_zone_names = local.selected_azs
  tags                    = local.common_tags
}
