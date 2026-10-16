variable "admin_cidr" {
  description = "IPv4 CIDR allowed to access the public EKS API endpoint"
  type        = string

  validation {
    condition     = can(cidrnetmask(var.admin_cidr))
    error_message = "admin_cidr must be a valid IPv4 CIDR, such as 203.0.113.10/32."
  }
}

variable "client_vpn_cidr" {
  description = "IPv4 CIDR range assigned to AWS Client VPN clients"
  type        = string
  default     = "172.21.0.0/22"

  validation {
    condition = can(cidrnetmask(var.client_vpn_cidr)) && try(
      tonumber(split("/", var.client_vpn_cidr)[1]) >= 12 &&
      tonumber(split("/", var.client_vpn_cidr)[1]) <= 22,
      false
    )
    error_message = "client_vpn_cidr must be a valid IPv4 CIDR with a prefix between /12 and /22."
  }
}


variable "cluster_admin_principal_arn" {
  description = "IAM user or role ARN authorized to administer the EKS cluster"
  type        = string

  validation {
    condition = can(regex(
      "^arn:aws(-[a-z]+)*:iam::[0-9]{12}:(user|role)/.+$",
      var.cluster_admin_principal_arn
    ))
    error_message = "Provide a valid IAM user or role ARN, such as arn:aws:iam::123456789012:user/admin."
  }
}



variable "client_vpn_server_certificate_arn" {
  description = "ACM ARN of the TLS server certificate for AWS Client VPN"
  type        = string

  validation {
    condition = can(regex(
      "^arn:aws(-[a-z]+)*:acm:us-east-1:[0-9]{12}:certificate/[0-9a-fA-F-]{36}$",
      var.client_vpn_server_certificate_arn
    ))
    error_message = "Provide a valid ACM certificate ARN in us-east-1."
  }
}

variable "client_vpn_root_certificate_arn" {
  description = "ACM ARN of the client certificate root CA for mutual authentication"
  type        = string

  validation {
    condition = can(regex(
      "^arn:aws(-[a-z]+)*:acm:us-east-1:[0-9]{12}:certificate/[0-9a-fA-F-]{36}$",
      var.client_vpn_root_certificate_arn
    ))
    error_message = "Provide a valid ACM certificate ARN in us-east-1."
  }
}



variable "db_instance_class" {
  description = "RDS MySQL instance class"
  type        = string
  default     = "db.t3.micro"

  validation {
    condition     = can(regex("^db\\.[a-z0-9]+\\.[a-z0-9]+$", var.db_instance_class))
    error_message = "Provide a validly formatted RDS instance class, such as db.t3.micro."
  }
}

variable "db_name" {
  description = "Application database name"
  type        = string
  default     = "UserDB"

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9]*$", var.db_name)) && length(var.db_name) <= 64
    error_message = "The database name must start with a letter, contain only letters and numbers, and be at most 64 characters."
  }
}

variable "db_master_username" {
  description = "RDS master username"
  type        = string
  default     = "dbadmin"

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9_]*$", var.db_master_username)) && length(var.db_master_username) <= 16 && lower(var.db_master_username) != "admin" && lower(var.db_master_username) != "root"
    error_message = "Use a valid MySQL master username of up to 16 characters; admin and root are not allowed."
  }
}

