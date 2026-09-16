module "zemechanics" {
  source = "./modules/lambda_apigateway"
 
  vpc_name         = "ze-mechanics-vpc"
  vpc_cidr         = "10.0.0.0/16"
}