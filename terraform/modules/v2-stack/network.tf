data "aws_vpc" "selected" {
  id = var.vpc_id
}
resource "aws_subnet" "public" {
  for_each                = var.public_subnets
  vpc_id                  = var.vpc_id
  availability_zone       = each.value.az
  cidr_block              = each.value.cidr
  map_public_ip_on_launch = true
  tags                    = { Name = "needu-${var.environment}-public-${each.key}" }
}
resource "aws_subnet" "db" {
  for_each          = var.db_subnets
  vpc_id            = var.vpc_id
  availability_zone = each.value.az
  cidr_block        = each.value.cidr
  tags              = { Name = "needu-${var.environment}-db-${each.key}" }
}
resource "aws_route_table" "public" {
  vpc_id = var.vpc_id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = var.igw_id
  }
  tags = { Name = "needu-${var.environment}-public-rt" }
}
resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table" "db" {
  vpc_id = var.vpc_id
  tags   = { Name = "needu-${var.environment}-db-rt" }
}
resource "aws_route_table_association" "db" {
  for_each       = aws_subnet.db
  subnet_id      = each.value.id
  route_table_id = aws_route_table.db.id
}
locals {
  public_subnet_ids = [for k in sort(keys(aws_subnet.public)) : aws_subnet.public[k].id]
  db_subnet_ids     = [for k in sort(keys(aws_subnet.db)) : aws_subnet.db[k].id]
}
