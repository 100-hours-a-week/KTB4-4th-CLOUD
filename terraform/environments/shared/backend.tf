terraform {
  backend "s3" {
    bucket       = "needu-terraform-state-919551759796"
    key          = "shared/terraform.tfstate"
    region       = "ap-northeast-2"
    encrypt      = true
    use_lockfile = true
  }
}