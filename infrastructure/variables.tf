variable "name_prefix" {
  default     = "the-book-boutique"
  description = "Prefix of the resource name."
}

variable "location" {
  default     = "eastus"
  description = "Location of the resource."
}

variable "login" {
  type    = string
  default = "shatha"
}

variable "password" {
  type    = string
  default = "H@Sh1CoR3!"
}
