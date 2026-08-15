# k8s-cluster-aws

**Version:** 0.2.0

<!--
  The line above is this module's version and the only place it is
  recorded — multicz rewrites it on bump (see `bump_files` in the repo-root
  multicz.toml), which is why there is no VERSION file here.

  Keep it ABOVE the BEGIN_TF_DOCS marker: terraform-docs replaces
  everything between the markers on every regeneration, so anything you
  put in there is lost.
-->

TODO: describe what `k8s-cluster-aws` creates and how a unit is expected to consume it.

## Usage

```hcl
# infrastructure/services/<unit>/terragrunt.hcl
terraform {
  source = "../../modules/k8s-cluster-aws"
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
| [aws_eks_cluster.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_cluster) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_cluster_role_arn"></a> [cluster\_role\_arn](#input\_cluster\_role\_arn) | IAM role the control plane assumes.<br/><br/>Created outside this module because the apply identity deliberately<br/>excludes IAM — see infrastructure/bootstrap/README.md. Granting the<br/>apply path the ability to create roles hands it a route to privilege<br/>escalation that no reviewer of a Terraform plan would see. | `string` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name — staging or production. Used for naming and tagging, never for behaviour. | `string` | n/a | yes |
| <a name="input_kubernetes_version"></a> [kubernetes\_version](#input\_kubernetes\_version) | Control plane version. Pinned rather than defaulted: an unpinned cluster upgrades on AWS's schedule rather than on a reviewed change. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name of the resource created by this module. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region the resources live in. | `string` | n/a | yes |
| <a name="input_security_group_id"></a> [security\_group\_id](#input\_security\_group\_id) | The workload group from services/network/firewall. | `string` | n/a | yes |
| <a name="input_service_cidr"></a> [service\_cidr](#input\_service\_cidr) | Range for ClusterIP services. Must not overlap the VPC — it is a<br/>virtual range inside the cluster, and an overlap makes some VPC address<br/>permanently unreachable from a pod, which presents as one service<br/>failing for no visible reason. | `string` | n/a | yes |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | Subnets the control plane's network interfaces live in — the workload<br/>subnets, which are private.<br/><br/>EKS requires at least two availability zones for the control plane even<br/>when the workloads run in one, which is why a single-zone staging still<br/>needs two entries here. | `list(string)` | n/a | yes |
| <a name="input_allow_self_managed_addons"></a> [allow\_self\_managed\_addons](#input\_allow\_self\_managed\_addons) | Kept as a documented false rather than removed, because the temptation<br/>to flip it is real and the reason not to belongs where someone would<br/>look.<br/><br/>Letting EKS install the VPC CNI and kube-proxy and deleting them<br/>afterwards leaves a window in which pods get the wrong datapath and no<br/>policy is enforced by anything — and nodes that join during it keep the<br/>old datapath until replaced. A cluster with no CNI is NotReady, which<br/>is loud; a cluster enforcing nothing looks healthy. | `bool` | `false` | no |
| <a name="input_enabled_log_types"></a> [enabled\_log\_types](#input\_enabled\_log\_types) | Control plane logs. All five by default.<br/><br/>api and audit are the two that answer "who did this?"; without them the<br/>question has no answer, and it is always asked after the fact. The<br/>other three answer "why did the cluster do that?" — a pod that never<br/>schedules or a controller that keeps retrying leaves its only trace<br/>there.<br/><br/>Dropping some is a cost decision. Make it deliberately, knowing which<br/>question stops being answerable. | `list(string)` | <pre>[<br/>  "api",<br/>  "audit",<br/>  "authenticator",<br/>  "controllerManager",<br/>  "scheduler"<br/>]</pre> | no |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | Key for envelope-encrypting Kubernetes secrets. Null leaves them encrypted with AWS's own key, which is true and says nothing about who can read them. | `string` | `null` | no |
| <a name="input_project"></a> [project](#input\_project) | GCP project. Null on AWS, where the account is implicit in the credentials. | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every resource this module creates. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_certificate_authority"></a> [certificate\_authority](#output\_certificate\_authority) | What a kubeconfig needs to trust the endpoint. |
| <a name="output_dataplane"></a> [dataplane](#output\_dataplane) | What enforces network policy in this cluster, stated so a plan answers<br/>it rather than a wiki.<br/><br/>The cluster is created with NO CNI: upstream Cilium is installed by the<br/>GitOps layer and replaces kube-proxy. Until it is, nodes are NotReady —<br/>which is the intended state, because a cluster enforcing nothing should<br/>not be able to accept a workload. |
| <a name="output_endpoint"></a> [endpoint](#output\_endpoint) | The private API endpoint. Reachable from inside the VPC and from nowhere else. |
| <a name="output_name"></a> [name](#output\_name) | Cluster name, consumed by services/k8s/nodes. |
| <a name="output_oidc_issuer"></a> [oidc\_issuer](#output\_oidc\_issuer) | The cluster's OIDC issuer, which is how a pod gets an AWS identity from its Kubernetes service account rather than borrowing the node's. |
<!-- END_TF_DOCS -->
