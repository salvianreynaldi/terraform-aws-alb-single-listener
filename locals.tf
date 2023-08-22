module "random_lb" {
  source = "git@github.com:traveloka/terraform-aws-resource-naming.git?ref=v0.22.0"

  name_prefix = format(
    "%s-%s",
    var.service_name,
    var.lb_internal ? "lbint" : "lbext",
  )
  resource_type = "lb"

  keepers = {
    lb_internal        = var.lb_internal
    lb_ip_address_type = var.lb_ip_address_type
    tg_port            = var.tg_port
    tg_protocol        = var.tg_protocol
    tg_vpc_id          = var.vpc_id
  }
}

module "random_tg" {
  source = "git@github.com:traveloka/terraform-aws-resource-naming.git?ref=v0.22.0"

  name_prefix   = format("%s-%s", var.service_name, var.cluster_role)
  resource_type = "lb_target_group"
}

module "random_tg_standby" {
  source = "git@github.com:traveloka/terraform-aws-resource-naming.git?ref=v0.22.0"

  name_prefix   = format("%s-%s", var.service_name, var.cluster_role)
  resource_type = "lb_target_group"
}

locals {
  lb_name         = var.lb_name == "" ? module.random_lb.name : var.lb_name
  tg_name         = var.tg_name == "" ? module.random_tg.name : var.tg_name
  tg_name_standby = module.random_tg_standby.name
}

locals {
  # as of terraform 0.12.31, it's not possible to have dynamic "ignore_changes"
  # https://github.com/hashicorp/terraform/issues/24188
  # so we need to separate rules that target the built-in target group (which changes should be ignored), from those that don't.
  listener_rules_builtin = { for k, v in var.listener_rules : k => v if lookup(v, "target_group_arn", null) == null }
  listener_rules_custom  = { for k, v in var.listener_rules : k => v if lookup(v, "target_group_arn", null) != null }

  tg_default_health_check = {
    "interval"            = 30
    "path"                = "/healthcheck"
    "healthy_threshold"   = 3
    "unhealthy_threshold" = 3
    "timeout"             = 5
    "protocol"            = "HTTP"
    "matcher"             = "200"
  }

  tg_health_check = merge(local.tg_default_health_check, var.tg_health_check)
}
