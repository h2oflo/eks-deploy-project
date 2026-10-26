locals {
  db_port = var.db_engine == "postgres" ? 5432 : 3306
}

resource "aws_security_group" "rds" {
  name_prefix = "${var.vpc_name}-rds-"
  description = "RDS access from within the vpc"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "DB port from within the VPC"
    from_port   = local.db_port
    to_port     = local.db_port
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = { Environment = "dev" }
}

resource "aws_db_instance" "rds_db_instance" {
  identifier            = "${var.vpc_name}-db"
  engine                = var.db_engine
  engine_version        = var.db_engine_version
  instance_class        = var.db_instance_class
  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name                     = var.db_name
  username                    = var.db_username
  manage_master_user_password = true # to be used once ESO is in the cluster

  db_subnet_group_name   = module.vpc.database_subnet_group_name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  multi_az                = false # change this to true before submitting
  backup_retention_period = 7
  skip_final_snapshot     = true # change this to true before submitting

  tags = { Environment = "dev" }
}

