data aws_caller_identity "current" {
}
resource "aws_cloudwatch_metric_alarm" "alarm_scale_down" {
  count             = length(var.autoscale) > 0 ? 1 : 0
  alarm_description = "Scale down alarm for ${var.service_name}"
  namespace         = "AWS/ApplicationELB"
  alarm_name        = "${var.prefix_name}-alarm-down"
  alarm_actions     = [aws_appautoscaling_policy.policy_scale_down[0].arn]

  comparison_operator = var.autoscale["scale_down_comparison_operator"]
  threshold           = var.autoscale["scale_down_threshold"]
  evaluation_periods  = var.autoscale["evaluation_periods"]
  metric_name         = var.autoscale["metric_name"]
  period              = lookup(var.autoscale, "period", 120)
  statistic           = lookup(var.autoscale, "statistic", "Average")
  datapoints_to_alarm = lookup(var.autoscale, "datapoints_to_alarm", 3)

  dimensions = {
    LoadBalancer = var.alb_suffix
  }
}


resource "aws_cloudwatch_metric_alarm" "alarm_scale_up" {
  count             = length(var.autoscale) > 0 ? 1 : 0
  alarm_description = "Scale up alarm for ${var.service_name}"
  namespace         = "AWS/ApplicationELB"
  alarm_name        = "${var.prefix_name}-alarm-up"
  alarm_actions     = [aws_appautoscaling_policy.policy_scale_up[0].arn]

  comparison_operator = var.autoscale["scale_up_comparison_operator"]
  threshold           = var.autoscale["scale_up_threshold"]
  evaluation_periods  = var.autoscale["evaluation_periods"]
  metric_name         = var.autoscale["metric_name"]
  period              = lookup(var.autoscale, "period", 180)
  statistic           = lookup(var.autoscale, "statistic", "Average")
  datapoints_to_alarm = lookup(var.autoscale, "datapoints_to_alarm", 3)

  dimensions = {
    LoadBalancer = var.alb_suffix
  }
}

resource "aws_appautoscaling_target" "ecs_target" {
  count        = length(var.autoscale) > 0 ? 1 : 0
  max_capacity = lookup(var.autoscale, "autoscale_max_capacity", 5)
  min_capacity = lookup(var.autoscale, "service_desired_count", 1)
  resource_id  = "service/${var.cluster}/${var.service_name}"
  role_arn = format(
    "arn:aws:iam::%s:role/aws-service-role/ecs.application-autoscaling.amazonaws.com/AWSServiceRoleForApplicationAutoScaling_ECSService",
    data.aws_caller_identity.current.account_id,
  )

  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}


resource "aws_appautoscaling_policy" "policy_scale_down" {
  count              = length(var.autoscale) > 0 ? 1 : 0
  name               = "${var.prefix_name}-policy-down"
  resource_id        = aws_appautoscaling_target.ecs_target[0].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target[0].service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = var.autoscale["adjustment_type"]
    cooldown                = var.autoscale["cooldown"]
    metric_aggregation_type = lookup(var.autoscale, "aggregation_type", "Average")

    step_adjustment {
      metric_interval_upper_bound = lookup(var.autoscale, "scale_down_interval_lower_bound", 0)
      scaling_adjustment          = var.autoscale["scale_down_adjustment"]
    }
  }
}


resource "aws_appautoscaling_policy" "policy_scale_up" {
  count              = length(var.autoscale) > 0 ? 1 : 0
  name               = "${var.prefix_name}-policy-up"
  resource_id        = aws_appautoscaling_target.ecs_target[0].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target[0].service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = var.autoscale["adjustment_type"]
    cooldown                = var.autoscale["cooldown"]
    metric_aggregation_type = lookup(var.autoscale, "aggregation_type", "Average")

    step_adjustment {
      metric_interval_lower_bound = lookup(var.autoscale, "scale_up_interval_lower_bound", 1)
      scaling_adjustment          = var.autoscale["scale_up_adjustment"]
    }
  }
}
