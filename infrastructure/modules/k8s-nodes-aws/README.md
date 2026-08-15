# k8s-nodes-aws

**Version:** 0.2.0

<!--
  The line above is this module's version and the only place it is
  recorded — multicz rewrites it on bump (see `bump_files` in the repo-root
  multicz.toml), which is why there is no VERSION file here.

  Keep it ABOVE the BEGIN_TF_DOCS marker: terraform-docs replaces
  everything between the markers on every regeneration, so anything you
  put in there is lost.
-->

TODO: describe what `k8s-nodes-aws` creates and how a unit is expected to consume it.

## Usage

```hcl
# infrastructure/services/<unit>/terragrunt.hcl
terraform {
  source = "../../modules/k8s-nodes-aws"
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
| [aws_eks_node_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_node_group) | resource |
| [aws_launch_template.nodes](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | The cluster this group joins, from services/k8s/cluster. | `string` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name — staging or production. Used for naming and tagging, never for behaviour. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name of the resource created by this module. | `string` | n/a | yes |
| <a name="input_node_role_arn"></a> [node\_role\_arn](#input\_node\_role\_arn) | IAM role the nodes assume.<br/><br/>Created outside this module because the apply identity deliberately<br/>excludes IAM — granting the apply path role creation hands it a route<br/>to privilege escalation no plan reviewer would see. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region the resources live in. | `string` | n/a | yes |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | Subnets the nodes sit in — THE WORKLOAD ONES, which have no default<br/>route.<br/><br/>The load-bearing setting here. AWS has no tag-scoped route, so which<br/>subnet a node sits in is what decides whether its egress reaches the<br/>proxy or an internet gateway. A public subnet would work, be fast, and<br/>bypass the proxy entirely. | `list(string)` | n/a | yes |
| <a name="input_capacity_type"></a> [capacity\_type](#input\_capacity\_type) | ON\_DEMAND or SPOT.<br/><br/>Spot is materially cheaper and can be reclaimed with two minutes'<br/>notice. It is a reasonable choice for a stateless workload and a poor<br/>one for a cluster whose egress path is a single proxy fleet — losing<br/>several nodes at once is exactly when everything tries to reconnect. | `string` | `"ON_DEMAND"` | no |
| <a name="input_disk_size_gb"></a> [disk\_size\_gb](#input\_disk\_size\_gb) | Node volume. Holds the image layers, which is usually what fills it. | `number` | `100` | no |
| <a name="input_ha"></a> [ha](#input\_ha) | Run the group across every workload subnet, with a higher floor. The difference between a zone failure costing capacity and costing the cluster. | `bool` | `false` | no |
| <a name="input_instance_types"></a> [instance\_types](#input\_instance\_types) | Node sizes. A list because a managed group falls back to the next type when the first is unavailable in a zone. | `list(string)` | <pre>[<br/>  "m6i.large"<br/>]</pre> | no |
| <a name="input_max_nodes"></a> [max\_nodes](#input\_max\_nodes) | Autoscaler ceiling without ha. | `number` | `3` | no |
| <a name="input_max_nodes_ha"></a> [max\_nodes\_ha](#input\_max\_nodes\_ha) | Autoscaler ceiling when ha is on. The number that decides the worst-case bill. | `number` | `15` | no |
| <a name="input_metadata_hop_limit"></a> [metadata\_hop\_limit](#input\_metadata\_hop\_limit) | How many network hops a metadata response may travel.<br/><br/>One puts the metadata service out of reach of every pod — a packet from<br/>a pod's namespace has already taken a hop — while leaving it reachable<br/>by the kubelet, which runs in the host namespace at zero hops.<br/><br/>Two is the value usually copied around, and it makes requiring IMDSv2<br/>only half a control: a pod can still ask, it just has to ask correctly.<br/>Raise it only for a workload that genuinely needs host-level metadata,<br/>knowing it then applies to every pod on the node. | `number` | `1` | no |
| <a name="input_min_nodes_ha"></a> [min\_nodes\_ha](#input\_min\_nodes\_ha) | Autoscaler floor when ha is on — one per zone for a three-zone production. | `number` | `3` | no |
| <a name="input_node_labels"></a> [node\_labels](#input\_node\_labels) | Kubernetes labels on every node in the group. | `map(string)` | `{}` | no |
| <a name="input_project"></a> [project](#input\_project) | GCP project. Null on AWS, where the account is implicit in the credentials. | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every resource this module creates. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_arn"></a> [arn](#output\_arn) | Node group ARN. |
| <a name="output_name"></a> [name](#output\_name) | Node group name. |
| <a name="output_subnet_ids"></a> [subnet\_ids](#output\_subnet\_ids) | Where the nodes actually sit. Exported so a plan can be checked against<br/>the workload subnets — the setting that decides whether egress reaches<br/>the proxy or an internet gateway. |
<!-- END_TF_DOCS -->
