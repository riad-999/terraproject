# Define the variables for Availability Zones and Region
variable "region" {
  description = "The AWS region to deploy resources in"
  type = string
  default = "us-east-1"
}

variable "zone1" {
  description = "First Availability Zone"
  type = string
  default = "us-east-1a"
}

variable "zone2" {
  description = "Second Availability Zone"
  type = string
  default = "us-east-1b"
}

variable "redis_instance_type" {
  type = string
  default = "cache.t2.micro"
}