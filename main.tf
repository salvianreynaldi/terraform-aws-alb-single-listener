# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#     http://www.apache.org/licenses/LICENSE_2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
resource "aws_lb" "main" {
  name     = local.lb_name
  internal = var.lb_internal

  security_groups = var.lb_security_groups

  subnets         = var.lb_subnet_ids
  idle_timeout    = var.lb_idle_timeout
  ip_address_type = var.lb_ip_address_type

  access_logs {
    bucket  = var.lb_logs_s3_bucket_name
    prefix  = local.lb_name
    enabled = true
  }

  tags = merge(
    {
      "Name"          = local.lb_name
      "Service"       = var.service_name
      "Environment"   = var.environment
      "ProductDomain" = var.product_domain
      "Description"   = var.description
      "ManagedBy"     = "terraform"
    },
    var.lb_tags,
  )
}

resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = var.listener_port
  protocol          = var.listener_protocol
  ssl_policy        = var.listener_protocol == "HTTPS" || var.listener_protocol == "TLS" ? var.listener_ssl_policy : null
  certificate_arn   = var.listener_certificate_arn

  default_action {
    type = "forward"

    forward {
      target_group {
        arn    = aws_lb_target_group.init_active.arn
        weight = 100
      }

      target_group {
        arn    = aws_lb_target_group.init_standby.arn
        weight = 0
      }
    }
  }

  lifecycle {
    ignore_changes = [
      default_action[0],
    ]
  }
}

resource "aws_lb_target_group" "init_active" {
  name                          = local.tg_name
  port                          = var.tg_port
  protocol                      = var.tg_protocol
  protocol_version              = var.tg_protocol_version
  vpc_id                        = var.vpc_id
  deregistration_delay          = var.tg_deregistration_delay
  target_type                   = var.tg_target_type
  slow_start                    = var.tg_slow_start
  load_balancing_algorithm_type = var.tg_algorithm_type

  dynamic "health_check" {
    for_each = [local.tg_health_check]
    content {
      enabled             = lookup(health_check.value, "enabled", null)
      healthy_threshold   = lookup(health_check.value, "healthy_threshold", null)
      interval            = lookup(health_check.value, "interval", null)
      matcher             = lookup(health_check.value, "matcher", null)
      path                = lookup(health_check.value, "path", null)
      port                = lookup(health_check.value, "port", null)
      protocol            = lookup(health_check.value, "protocol", null)
      timeout             = lookup(health_check.value, "timeout", null)
      unhealthy_threshold = lookup(health_check.value, "unhealthy_threshold", null)
    }
  }

  tags = merge(
    {
      "Name"          = local.tg_name
      "Service"       = var.service_name
      "Environment"   = var.environment
      "ProductDomain" = var.product_domain
      "Description"   = var.description
      "ManagedBy"     = "terraform"
    },
    var.tg_tags,
  )
}

resource "aws_lb_listener_rule" "custom" {
  for_each     = local.listener_rules_custom
  listener_arn = aws_lb_listener.main.arn

  priority = each.key

  action {
    type             = "forward"
    target_group_arn = each.value["target_group_arn"]
  }

  dynamic "condition" {
    for_each = each.value["conditions"]
    content {
      dynamic "host_header" {
        for_each = lookup(condition.value, "field", null) == "host-header" ? [" using host header "] : []
        content {
          values = lookup(condition.value, "values", null)
        }
      }
      dynamic "path_pattern" {
        for_each = lookup(condition.value, "field", null) == "path-pattern" ? [" using path pattern "] : []
        content {
          values = lookup(condition.value, "values", null)
        }
      }
    }
  }
  lifecycle {
    ignore_changes = [
      action[0],
    ]
  }
}

resource "aws_lb_listener_rule" "builtin" {
  for_each     = local.listener_rules_builtin
  listener_arn = aws_lb_listener.main.arn

  priority = each.key

  action {
    type = "forward"

    forward {
      target_group {
        arn    = aws_lb_target_group.init_active.arn
        weight = 100
      }

      target_group {
        arn    = aws_lb_target_group.init_standby.arn
        weight = 0
      }
    }
  }

  dynamic "condition" {
    # each.value["conditions"] here contains a list of conditions, e.g.
    # [{
    #     "field"  = "host-header"
    #     "values" = ["m.traveloka.com"]
    #   },
    #   {
    #     "field"  = "path-pattern"
    #     "values" = ["/frontend/"]
    # }]
    for_each = each.value["conditions"]
    content {
      dynamic "host_header" {
        for_each = lookup(condition.value, "field", null) == "host-header" ? [" using host header "] : []
        content {
          values = lookup(condition.value, "values", null)
        }
      }
      dynamic "path_pattern" {
        for_each = lookup(condition.value, "field", null) == "path-pattern" ? [" using path pattern "] : []
        content {
          values = lookup(condition.value, "values", null)
        }
      }
    }
  }
  lifecycle {
    ignore_changes = [
      action[0],
    ]
  }
}

resource "aws_lb_target_group" "init_standby" {
  name                          = local.tg_name_standby
  port                          = var.tg_port
  protocol                      = var.tg_protocol
  vpc_id                        = var.vpc_id
  deregistration_delay          = var.tg_deregistration_delay
  target_type                   = var.tg_target_type
  slow_start                    = var.tg_slow_start
  load_balancing_algorithm_type = var.tg_algorithm_type

  dynamic "health_check" {
    for_each = [local.tg_health_check]
    content {
      enabled             = lookup(health_check.value, "enabled", null)
      healthy_threshold   = lookup(health_check.value, "healthy_threshold", null)
      interval            = lookup(health_check.value, "interval", null)
      matcher             = lookup(health_check.value, "matcher", null)
      path                = lookup(health_check.value, "path", null)
      port                = lookup(health_check.value, "port", null)
      protocol            = lookup(health_check.value, "protocol", null)
      timeout             = lookup(health_check.value, "timeout", null)
      unhealthy_threshold = lookup(health_check.value, "unhealthy_threshold", null)
    }
  }

  tags = merge(
    {
      "Name"          = local.tg_name_standby
      "Service"       = var.service_name
      "Environment"   = var.environment
      "ProductDomain" = var.product_domain
      "Description"   = var.description
      "ManagedBy"     = "terraform"
    },
    var.tg_tags,
  )
}
