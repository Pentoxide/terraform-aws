variable "region" {
  default = "eu-north-1"
}

variable "instances" {
  type = map(string)
  default = {
    "eu-north-1" = "t3.micro"
  }
}

variable "images" {
  type = map(string)
  default = {
    "us-east-1" = "ami-b374d5a5"
    "us-west-2" = "ami-4b32be2b"
    "eu-north-1" = "ami-9f35bde1"
  }
}

variable "private_key" {
  type = string
}
