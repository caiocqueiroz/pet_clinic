#subnet for ECS in AZ 1a - getting vpc id from remote state
resource "aws_subnet" "subnet" {
  vpc_id                  = data.terraform_remote_state.vpc.outputs.vpc_id
  cidr_block              = cidrsubnet(data.terraform_remote_state.vpc.outputs.cidr_block, 8, 2)
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
  tags = {
    Name = "pet clinic subnet 1a"
  }
}
#subnet for ECS in AZ 1a - getting vpc id from remote state
resource "aws_subnet" "subnet2" {
  vpc_id                  = data.terraform_remote_state.vpc.outputs.vpc_id
  cidr_block              = cidrsubnet(data.terraform_remote_state.vpc.outputs.cidr_block, 8, 3)
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1b"

  tags = {
    Name = "pet clinic subnet 1a"
  }
}

# Route table association with the subnet 1a, getting route table id from remote state
resource "aws_route_table_association" "subnet_route" {
  subnet_id      = aws_subnet.subnet.id
  route_table_id = data.terraform_remote_state.vpc.outputs.rt_id
}

# Route table association with the subnet 1b, getting route table id from remote state
resource "aws_route_table_association" "subnet2_route" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = data.terraform_remote_state.vpc.outputs.rt_id
}

#security groups for the the subnets, allowing full ingress and eggress access.
resource "aws_security_group" "security_group" {
  name   = "ecs-security-group"
  vpc_id = data.terraform_remote_state.vpc.outputs.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    self        = "false"
    cidr_blocks = ["0.0.0.0/0"]
    description = "any"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}