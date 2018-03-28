locals {
  target_group_arns = "${concat(list(aws_lb_target_group.default.arn), var.target_group_arns)}"
}

locals {
  r53_record_name = "${var.r53_record_name == "" ? format("%s-%s", var.tag_service_name, var.tag_environment) : var.r53_record_name}"
}
