terraform {
  backend "s3" {
    bucket       = "needu-terraform-state-919551759796"
    key          = "bootstrap/terraform.tfstate"
    region       = "ap-northeast-2"
    encrypt      = true
    use_lockfile = true
  }
}