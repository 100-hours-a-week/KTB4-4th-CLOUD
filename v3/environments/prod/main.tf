data "aws_vpc" "existing" { id = var.vpc_id }
data "aws_subnet" "public_a" { id = var.existing_public_subnet_ids[0] }
data "aws_subnet" "public_c" { id = var.existing_public_subnet_ids[1] }
data "aws_internet_gateway" "existing" { internet_gateway_id = var.internet_gateway_id }

locals {
  az_subnets = zipmap(var.availability_zones, var.private_subnet_cidrs)
  system_azs = toset(slice(var.availability_zones, 0, 2))
}

resource "aws_subnet" "public_b" {
  vpc_id                  = data.aws_vpc.existing.id
  availability_zone       = var.availability_zones[1]
  cidr_block              = var.new_public_subnet_cidr
  map_public_ip_on_launch = false
  tags = {
    Name                     = "${var.name}-public-b"
    "kubernetes.io/role/elb" = "1"
  }
}
resource "aws_route_table" "public_b" {
  vpc_id = data.aws_vpc.existing.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = data.aws_internet_gateway.existing.id
  }
  tags = { Name = "${var.name}-public-b-rt" }
}
resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public_b.id
}

resource "aws_subnet" "private" {
  for_each          = local.az_subnets
  vpc_id            = data.aws_vpc.existing.id
  availability_zone = each.key
  cidr_block        = each.value
  tags = {
    Name                              = "${var.name}-private-${each.key}"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_nat_gateway" "regional" {
  vpc_id            = data.aws_vpc.existing.id
  availability_mode = "regional"
  connectivity_type = "public"
  tags              = { Name = "${var.name}-regional-nat" }
  depends_on        = [data.aws_internet_gateway.existing]
}
resource "aws_route_table" "private" {
  vpc_id = data.aws_vpc.existing.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.regional.id
  }
  tags = { Name = "${var.name}-private-rt" }
}
resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

module "eks" {
  source                 = "../../modules/eks-prod"
  name                   = var.name
  cluster_version        = var.cluster_version
  private_subnet_ids     = [for az in var.availability_zones : aws_subnet.private[az].id]
  availability_zones     = var.availability_zones
  node_instance_types    = var.node_instance_types
  system_max_per_az      = var.system_max_per_az
  app_max_per_az         = var.app_max_per_az
  public_access_cidrs    = var.eks_public_access_cidrs
  cluster_admin_role_arn = var.eks_cluster_admin_role_arn
}
