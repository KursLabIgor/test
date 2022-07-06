variable "autoscale" {
  description = "An autoscale block"
  type        = map(string)
  default     = {}
}
variable "cluster" {}
variable "service_name" {}
variable "alb_suffix" {}
variable "prefix_name" {}