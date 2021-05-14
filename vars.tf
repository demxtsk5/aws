# Variablen
variable "region" {
  default = "eu-central-1"
}
variable "zone1" {
  description = "Zone 1"
  default = "eu-central-1b"
}
variable "cidr" {
  description = "Main CIDR"
  default = "10.0.0.0/21"  
}
variable "pub_net" {
  description = "Public Network"
  default = "10.0.1.0/24"  
}
variable "pri_net" {
  description = "Private Network"
  default = "10.0.2.0/24"  
}
variable "ami_ident" {
  description = "AMI Identifier"
  default = "ami-043097594a7df80ec"  
}
variable "ami_type" {
  description = "AMI Type"
  default = "t2.micro"
}
variable "my_tag" {
  type = string
  default = "mg0050"
}
variable "lb_name" {
  default = "mg0050-lb"
}