# API GATEWAY CONFIGS

# HTTP API
resource "aws_apigatewayv2_api" "zemechanic_api" {
  name          = "zemechanic_api"
  protocol_type = "HTTP"
}

# STAGE: PROD
resource "aws_apigatewayv2_stage" "example" {
  api_id = aws_apigatewayv2_api.zemechanic_api.id
  name   = "prod"
  auto_deploy = true

  depends_on = [ aws_apigatewayv2_api.zemechanic_api ]
}

# INTEGRATION: AUTH ISSUER (JWT)
resource "aws_apigatewayv2_integration" "integration-ze_mechanic_auth_issuer" {
  api_id           = aws_apigatewayv2_api.zemechanic_api.id
  integration_type = "AWS_PROXY"

  connection_type           = "INTERNET"
  integration_uri           = aws_lambda_function.lambda-zemechanic-auth-issuer.invoke_arn

  depends_on = [ aws_lambda_function.lambda-zemechanic-auth-issuer, aws_apigatewayv2_stage.example ]
}

# ROUTE 01: /auth/login (PUBLIC - GENERATE JWT TOKEN)
resource "aws_apigatewayv2_route" "route-auth-login" {
  api_id    = aws_apigatewayv2_api.zemechanic_api.id
  route_key = "POST /auth/login"
  target = "integrations/${aws_apigatewayv2_integration.integration-ze_mechanic_auth_issuer.id}"

  depends_on = [ aws_apigatewayv2_integration.integration-ze_mechanic_auth_issuer ]
}

# ADD: LAMBDA INVOKE FUNCTION ROLE
resource "aws_lambda_permission" "allow_apigw_invoke_auth_issuer" {
  statement_id  = "AllowAPIGatewayInvokeAuthIssuer"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda-zemechanic-auth-issuer.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.zemechanic_api.execution_arn}/*/*"

  depends_on = [ aws_apigatewayv2_api.zemechanic_api, aws_lambda_function.lambda-zemechanic-auth-issuer ]
}

# AUTHORIZER - LAMBDA: zemechanic-auth
resource "aws_apigatewayv2_authorizer" "authorizer-zemechanic-auth" {
  api_id           = aws_apigatewayv2_api.zemechanic_api.id
  authorizer_type  = "REQUEST"
  authorizer_uri   = aws_lambda_function.auth-lambda.invoke_arn
  identity_sources = ["$request.header.Authorization"]
  name             = "auth-authorizer"
  enable_simple_responses = true
  authorizer_result_ttl_in_seconds = 300
  authorizer_payload_format_version = "2.0"

}

# AUTHORIZER - IAM
resource "aws_lambda_permission" "allow_apigw_invoke_auth" {
  statement_id  = "AllowAPIGatewayInvokeAuth"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auth-lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.zemechanic_api.execution_arn}/authorizers/${aws_apigatewayv2_authorizer.authorizer-zemechanic-auth.id}"
}

# VPC LINK
resource "aws_apigatewayv2_vpc_link" "zemechanic" {
  name               = "zemechanic-vpc-link"
  security_group_ids = [aws_security_group.eks-sg.id]
  subnet_ids = [
    aws_subnet.us-east-1a-priv.id,
    aws_subnet.us-east-1b-priv.id,
  ]
}

data "aws_lb" "ingress_nlb" {

  tags = {
    "kubernetes.io/cluster/zemechanics-cluster" = "owned"
    "kubernetes.io/service-name"                = "ingress-nginx/ingress-nginx-controller"
  }
}

data "aws_lb_listener" "ingress_listener" {
  load_balancer_arn = data.aws_lb.ingress_nlb.arn
  port               = 80
}

# INTEGRATION:
resource "aws_apigatewayv2_integration" "eks_proxy" {
  api_id                 = aws_apigatewayv2_api.zemechanic_api.id
  integration_type       = "HTTP_PROXY"
  integration_uri        = data.aws_lb_listener.ingress_listener.arn
  integration_method     = "ANY"
  connection_type        = "VPC_LINK"
  connection_id          = aws_apigatewayv2_vpc_link.zemechanic.id
  payload_format_version = "1.0"

  request_parameters = {
    "overwrite:path" = "$request.path"
  }
}

# PROXY: CATCH ALL
resource "aws_apigatewayv2_route" "protected_proxy" {
  api_id             = aws_apigatewayv2_api.zemechanic_api.id
  route_key          = "ANY /{proxy+}"
  target             = "integrations/${aws_apigatewayv2_integration.eks_proxy.id}"
  authorization_type = "CUSTOM"
  authorizer_id      = aws_apigatewayv2_authorizer.authorizer-zemechanic-auth.id
}

##############################################
# Rotas públicas — Ordem de Serviço          #
##############################################
resource "aws_apigatewayv2_route" "os_pagina_aprovacao" {
  api_id    = aws_apigatewayv2_api.zemechanic_api.id
  route_key = "GET /api/v1/ordem_servico/aprovar/{os_id}"
  target    = "integrations/${aws_apigatewayv2_integration.eks_proxy.id}"
}

resource "aws_apigatewayv2_route" "os_confirmar_aprovacao" {
  api_id    = aws_apigatewayv2_api.zemechanic_api.id
  route_key = "POST /api/v1/ordem_servico/confirmar_aprovacao/{os_id}"
  target    = "integrations/${aws_apigatewayv2_integration.eks_proxy.id}"
}

resource "aws_apigatewayv2_route" "os_reprovar" {
  api_id    = aws_apigatewayv2_api.zemechanic_api.id
  route_key = "POST /api/v1/ordem_servico/reprovar/{os_id}"
  target    = "integrations/${aws_apigatewayv2_integration.eks_proxy.id}"
}

##############################################
# Rotas públicas — Health, Docs, Static      #
##############################################
resource "aws_apigatewayv2_route" "health_live" {
  api_id    = aws_apigatewayv2_api.zemechanic_api.id
  route_key = "GET /api/v1/health/live"
  target    = "integrations/${aws_apigatewayv2_integration.eks_proxy.id}"
}

resource "aws_apigatewayv2_route" "health_ready" {
  api_id    = aws_apigatewayv2_api.zemechanic_api.id
  route_key = "GET /api/v1/health/ready"
  target    = "integrations/${aws_apigatewayv2_integration.eks_proxy.id}"
}

resource "aws_apigatewayv2_route" "docs" {
  api_id    = aws_apigatewayv2_api.zemechanic_api.id
  route_key = "GET /docs"
  target    = "integrations/${aws_apigatewayv2_integration.eks_proxy.id}"
}

resource "aws_apigatewayv2_route" "openapi_json" {
  api_id    = aws_apigatewayv2_api.zemechanic_api.id
  route_key = "GET /openapi.json"
  target    = "integrations/${aws_apigatewayv2_integration.eks_proxy.id}"
}

resource "aws_apigatewayv2_route" "static_assets" {
  api_id    = aws_apigatewayv2_api.zemechanic_api.id
  route_key = "GET /static/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.eks_proxy.id}"
}

##############################################
# 13. Rota pública — Registro de cliente
##############################################
resource "aws_apigatewayv2_route" "auth_registrar" {
  api_id    = aws_apigatewayv2_api.zemechanic_api.id
  route_key = "POST /api/v1/cliente/novo_cliente"
  target    = "integrations/${aws_apigatewayv2_integration.eks_proxy.id}"
}