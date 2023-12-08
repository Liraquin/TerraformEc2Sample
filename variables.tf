variable "region" {
  type = string
  default = "us-east-1"
}

variable "vpcid" {
  type = string
  default = "vpc-ID"
}

variable "subnetids" {
    type = list(string)
    default = [ "subnet-ID", "subnet-ID2", "subnet-ID3"]
}

variable "cidrb" {
  type = list(string)
  default = [ "10.0.0.0/8", ]
}

variable "instance_profile" {
    type = string
    default = "PROJECT_NAME_ROLE"
}

variable "ssl_policy" {
  type = string
  default = "ELBSecurityPolicy-TLS13-1-2-Ext1-2021-06"
}

variable "certificate_arn" {
  type = string
  default = "arn:aws:acm:us-east-1:ID:certificate/ID"
}
variable "amiid" {
    type = string
}

variable "instancetype" {
    type = string
}

variable "keyname" {
    type = string
}

variable "to_tag" {
  default = ["volume", "network-interface"]
}

variable "default_tags" {
    description = "Default billing tags to be applied across all resources"
    type        = map(string)
    default = {
        team              = "TEAM",
        application       = "PROJECT_NAME",
        terraform         = "True"
        env               = "prod"
        cloud-cost-center = "CCC_GOES_HERE"
    }
}