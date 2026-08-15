# network-firewall-aws

**Version:** 0.2.0

<!--
  The line above is this module's version and the only place it is
  recorded — multicz rewrites it on bump (see `bump_files` in the repo-root
  multicz.toml), which is why there is no VERSION file here.

  Keep it ABOVE the BEGIN_TF_DOCS marker: terraform-docs replaces
  everything between the markers on every regeneration, so anything you
  put in there is lost.
-->

TODO: describe what `network-firewall-aws` creates and how a unit is expected to consume it.

## Usage

```hcl
# infrastructure/services/<unit>/terragrunt.hcl
terraform {
  source = "../../modules/network-firewall-aws"
}

inputs = {
  name = local.config.services.<unit>.name
  tags = local.config.tags
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 6.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_security_group.endpoints](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.lb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.proxy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.workload](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_endpoint.interface](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_security_group_egress_rule.lb_to_workload](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.proxy_to_internet](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.workload_internal](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.workload_to_endpoints](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.workload_to_proxy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.endpoints_from_workload](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.lb_ingress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.proxy_from_workload](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.workload_from_lb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.workload_internal](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name — staging or production. Used for naming and tagging, never for behaviour. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name of the resource created by this module. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region the resources live in. | `string` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | The VPC these groups belong to, from services/network/vpc. | `string` | n/a | yes |
| <a name="input_interface_endpoints"></a> [interface\_endpoints](#input\_interface\_endpoints) | AWS services reachable over private addresses. Null takes the default<br/>set: Session Manager, ECR, CloudWatch Logs and STS — the minimum for a<br/>node to be reachable, pull an image and say anything about itself.<br/><br/>Each costs an hourly charge per zone, which is the usual reason someone<br/>removes one and reaches for a NAT instead. | `list(string)` | `null` | no |
| <a name="input_lb_ingress_cidrs"></a> [lb\_ingress\_cidrs](#input\_lb\_ingress\_cidrs) | Who may reach the load balancer.<br/><br/>THE ONE PER-ENVIRONMENT DECISION IN THIS MODULE. Production is public<br/>and passes 0.0.0.0/0; staging passes its own ranges and gets an<br/>internal front end from the same code. Empty means the load balancer<br/>accepts nothing, which is the correct resting state before an<br/>environment has decided. | `list(string)` | `[]` | no |
| <a name="input_node_port_range"></a> [node\_port\_range](#input\_node\_port\_range) | Kubernetes NodePort range, the ports the load balancer reaches on a node. | `list(number)` | <pre>[<br/>  30000,<br/>  32767<br/>]</pre> | no |
| <a name="input_project"></a> [project](#input\_project) | GCP project. Null on AWS, where the account is implicit in the credentials. | `string` | `null` | no |
| <a name="input_proxy_egress_ports"></a> [proxy\_egress\_ports](#input\_proxy\_egress\_ports) | What the proxies themselves may reach on the internet.<br/><br/>Deliberately not "all": a proxy that can open any port is a tunnel out<br/>for anything that reaches it, which is most of the estate. | `list(number)` | <pre>[<br/>  80,<br/>  443<br/>]</pre> | no |
| <a name="input_proxy_port"></a> [proxy\_port](#input\_proxy\_port) | The port Squid listens on. The workload may reach the proxy on this port and no other. | `number` | `3128` | no |
| <a name="input_s3_endpoint_enabled"></a> [s3\_endpoint\_enabled](#input\_s3\_endpoint\_enabled) | Attach the S3 gateway endpoint. It is free, and ECR image layers live in S3. | `bool` | `true` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every resource this module creates. | `map(string)` | `{}` | no |
| <a name="input_workload_route_table_ids"></a> [workload\_route\_table\_ids](#input\_workload\_route\_table\_ids) | Route tables the S3 gateway endpoint attaches to — the workload ones,<br/>which have no default route.<br/><br/>Without it a node cannot reach S3 at all, and ECR stores every image<br/>layer there, so the symptom is an image pull that fails partway with a<br/>network error rather than an access one. | `list(string)` | `[]` | no |
| <a name="input_workload_subnet_ids"></a> [workload\_subnet\_ids](#input\_workload\_subnet\_ids) | Subnets the interface endpoints put an ENI in. One per zone, so a zone failure does not take the API with it. | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_endpoints_security_group_id"></a> [endpoints\_security\_group\_id](#output\_endpoints\_security\_group\_id) | Group for the VPC interface endpoints. Answers, never initiates. |
| <a name="output_lb_is_public"></a> [lb\_is\_public](#output\_lb\_is\_public) | Whether this environment's load balancer accepts traffic from the<br/>internet. Only production should read true, and reading it from a plan<br/>beats inferring it from a list of ranges. |
| <a name="output_lb_security_group_id"></a> [lb\_security\_group\_id](#output\_lb\_security\_group\_id) | Group for the load balancer front end. |
| <a name="output_proxy_security_group_id"></a> [proxy\_security\_group\_id](#output\_proxy\_security\_group\_id) | Group for the egress proxies. The only one permitted to reach the internet. |
| <a name="output_workload_security_group_id"></a> [workload\_security\_group\_id](#output\_workload\_security\_group\_id) | Group for the nodes pods run on. Its egress is the proxy and the endpoints, and nothing else. |
<!-- END_TF_DOCS -->
