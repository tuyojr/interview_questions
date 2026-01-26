<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.28.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_dashboard.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_dashboard) | resource |
| [aws_cloudwatch_log_group.alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.backend](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.frontend](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_metric_alarm.alb_response_time](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.alb_unhealthy_hosts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.asg_cpu_high](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alb_arn_suffix"></a> [alb\_arn\_suffix](#input\_alb\_arn\_suffix) | ARN suffix of the Application Load Balancer | `string` | n/a | yes |
| <a name="input_alb_response_time_threshold"></a> [alb\_response\_time\_threshold](#input\_alb\_response\_time\_threshold) | Threshold for ALB response time alarm (seconds) | `number` | `2` | no |
| <a name="input_asg_name"></a> [asg\_name](#input\_asg\_name) | Name of the Auto Scaling Group | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS Region | `string` | n/a | yes |
| <a name="input_cpu_high_threshold"></a> [cpu\_high\_threshold](#input\_cpu\_high\_threshold) | Threshold for CPU high alarm (percentage) | `number` | `80` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name | `string` | n/a | yes |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Number of days to retain CloudWatch logs | `number` | `7` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to resources | `map(string)` | `{}` | no |
| <a name="input_target_group_arn_suffix"></a> [target\_group\_arn\_suffix](#input\_target\_group\_arn\_suffix) | ARN suffix of the target group | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_alb_log_group_arn"></a> [alb\_log\_group\_arn](#output\_alb\_log\_group\_arn) | ARN of the ALB CloudWatch log group |
| <a name="output_alb_log_group_name"></a> [alb\_log\_group\_name](#output\_alb\_log\_group\_name) | Name of the ALB CloudWatch log group |
| <a name="output_alb_response_time_alarm_arn"></a> [alb\_response\_time\_alarm\_arn](#output\_alb\_response\_time\_alarm\_arn) | ARN of the ALB response time alarm |
| <a name="output_alb_unhealthy_hosts_alarm_arn"></a> [alb\_unhealthy\_hosts\_alarm\_arn](#output\_alb\_unhealthy\_hosts\_alarm\_arn) | ARN of the ALB unhealthy hosts alarm |
| <a name="output_asg_cpu_high_alarm_arn"></a> [asg\_cpu\_high\_alarm\_arn](#output\_asg\_cpu\_high\_alarm\_arn) | ARN of the ASG CPU high alarm |
| <a name="output_backend_log_group_arn"></a> [backend\_log\_group\_arn](#output\_backend\_log\_group\_arn) | ARN of the backend CloudWatch log group |
| <a name="output_backend_log_group_name"></a> [backend\_log\_group\_name](#output\_backend\_log\_group\_name) | Name of the backend CloudWatch log group |
| <a name="output_dashboard_name"></a> [dashboard\_name](#output\_dashboard\_name) | Name of the CloudWatch dashboard |
| <a name="output_frontend_log_group_arn"></a> [frontend\_log\_group\_arn](#output\_frontend\_log\_group\_arn) | ARN of the frontend CloudWatch log group |
| <a name="output_frontend_log_group_name"></a> [frontend\_log\_group\_name](#output\_frontend\_log\_group\_name) | Name of the frontend CloudWatch log group |
<!-- END_TF_DOCS -->