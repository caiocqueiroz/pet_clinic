data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = "dev-tf-states-kqz"
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}