terraform {
  backend "s3" {
    bucket = "dev-tf-states-kqz"
    key    = "pet-clinic-terraform.tfstate"
    region = "us-east-1"

  }
}