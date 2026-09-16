# LAMBDA: AUTH ISSUER (JWT)

resource "aws_iam_policy" "auth_issuer_lambda_vpc_policy" {
  name        = "lambda_vpc"
  path        = "/"
  description = "Allow Lambda to connect to a VPC"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeNetworkInterfaceAttribute",
          "ec2:DeleteNetworkInterface",
          "ec2:AssignPrivateIpAddresses",   # Obrigatório para Lambda na VPC
          "ec2:UnassignPrivateIpAddresses"  # Obrigatório para Lambda na VPC
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_policy" "auth_issuer_lambda_rds_policy" {
  name        = "lambda_rds_connect"
  path        = "/"
  description = "Allow Lambda to connect to an RDS instance via IAM Authentication"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rds-db:connect"
        ]
        Resource = "*" # Para maior segurança no futuro, você pode substituir pelo ARN do seu usuário do banco/RDS
      }
    ]
  })
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = "lambda_execution_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "vpc_policy_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.auth_issuer_lambda_vpc_policy.arn
}

resource "aws_iam_role_policy_attachment" "rds_policy_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.auth_issuer_lambda_rds_policy.arn
}

data "http" "rds_cert" {
  url = "https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem"
}

resource "local_file" "rds_cert_file" {
  content  = data.http.rds_cert.response_body
  filename = "${path.module}/code/auth_issuer/global-bundle.pem"
}

data "archive_file" "lambda_zip-auth-issuer" {
  type        = "zip"
  source_dir  = "${path.module}/code/auth_issuer/"
  output_path = "${path.module}/lambda_function.zip"

  depends_on = [local_file.rds_cert_file]
}

resource "aws_lambda_function" "lambda-zemechanic-auth-issuer" {
  filename         = data.archive_file.lambda_zip-auth-issuer.output_path
  function_name = "zemechanic-auth-issuer-2"
  role          = aws_iam_role.lambda_role.arn
  handler       = "ze_mechanic_auth_issuer.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip-auth-issuer.output_base64sha256

  runtime = "python3.13"

  environment {
    variables = {
      DB_HOST = "DB_URL"
      DB_PORT = "DB_PORT"
      DB_USER = "DB_USER"
      DB_NAME = "DB_NAME"
      DB_PASSWORD = "DB_PASSWORD"
      JWT_SECRET = "JWT_SECRET"
    }
  }

  tags = {
    Environment = "production"
    Application = "zemechanics"
  }

  timeout = 60

  vpc_config {
    security_group_ids = [ aws_security_group.lambda-sg.id ]
    subnet_ids = [ aws_subnet.us-east-1a-pub.id , aws_subnet.us-east-1b-pub.id ]
  }
}

# LAMBDA: AUTH
data "archive_file" "lambda_zip-auth" {
  type        = "zip"
  source_dir  = "${path.module}/code/auth/"
  output_path = "${path.module}/lambda_function_auth.zip"

}

resource "aws_lambda_function" "auth-lambda" {
  filename         = data.archive_file.lambda_zip-auth.output_path
  function_name = "zemechanic-auth"
  role          = aws_iam_role.lambda_role.arn
  handler       = "ze_mechanic_auth.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip-auth.output_base64sha256

  runtime = "python3.13"

  environment {
    variables = {
      JWT_SECRET = "admin123"
    }
  }

  tags = {
    Environment = "production"
    Application = "zemechanics"
  }

  timeout = 60

  vpc_config {
    security_group_ids = [ aws_security_group.lambda-sg.id ]
    subnet_ids = [ aws_subnet.us-east-1a-pub.id , aws_subnet.us-east-1b-pub.id ]
  }
}
