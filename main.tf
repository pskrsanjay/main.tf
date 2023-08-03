provider "aws" {
  region     = "us-west-1"
  access_key = "AKIASEGB5GMCSJWQKO5P"
  secret_key = "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"
}
## Code for vpc, subnets, load balancer ##

resource "aws_vpc" "sanjay_vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "dev_public_a" {
  vpc_id     = aws_vpc.sanjay_vpc.id
  cidr_block = "10.0.64.0/19"
}

resource "aws_subnet" "dev_public_b" {
  vpc_id     = aws_vpc.sanjay_vpc.id
  cidr_block = "10.0.96.0/19"
}

resource "aws_subnet" "dev_private_a" {
  vpc_id     = aws_vpc.sanjay_vpc.id
  cidr_block = "10.0.192.0/20"
}

resource "aws_subnet" "dev_private_b" {
  vpc_id     = aws_vpc.sanjay_vpc.id
  cidr_block = "10.0.208.0/20"
}

resource "aws_security_group" "sanjay_sg" {
  name_prefix = "sanjay-sg"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "sanjay_lb" {
  name               = "sanjay-lb"
  internal           = false
  load_balancer_type = "application"
  subnets            = [aws_subnet.dev_public_a.id, aws_subnet.dev_public_b.id]
  security_groups    = [aws_security_group.sanjay_sg.id]
}

resource "aws_lb_target_group" "sanjay_target_group" {
  name     = "sanjay-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.sanjay_vpc.id
}

resource "aws_lb_listener" "sanjay_listener" {
  load_balancer_arn = aws_lb.sanjay_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.sanjay_target_group.arn
  }
}

## ECS ##

resource "aws_ecs_cluster" "sanjay_cluster" {
  name = "sanjay-cluster"
}

resource "aws_ecs_task_definition" "sanjay_task" {
  family = "sanjay-task"
  container_definitions = jsonencode([{
    name  = "sanjay-container"
    image = "nginx:latest"
    portMappings = [{
      containerPort = 80
      hostPort      = 80
      protocol      = "tcp"
    }]
  }])

  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
}

resource "aws_ecs_service" "sanjay_service" {
  name            = "sanjay-service"
  cluster         = aws_ecs_cluster.sanjay_cluster.id
  task_definition = aws_ecs_task_definition.sanjay_task.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    security_groups = [aws_security_group.sanjay_sg.id]
    subnets         = [aws_subnet.dev_public_a.id]
  }

  load_balancer {
    target_group_arn = "arn:aws:elasticloadbalancing:us-west-2:123456789012:targetgroup/example-tg/abcdef1234567890" ##
    container_name   = "sanjay-container"
    container_port   = 80
  }
}
