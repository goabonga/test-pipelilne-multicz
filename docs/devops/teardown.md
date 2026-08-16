---
icon: lucide/trash-2
---

# Teardown

Destroys the parts of an environment that cost money while idle, without
dismantling the environment.

## Doing it

```bash
git commit -m "chore: park staging overnight" -m "Teardown: staging"
git push
```

Then approve the `destroy` job when GitHub asks. There is also a manual
`workflow_dispatch` if you would rather not commit anything.

## What it destroys

Whatever the environment's config declares, in the order it declares:

```yaml
teardown:
  - k8s/nodes
  - k8s/cluster
  - vms/proxy
  - network/nat
```

**The list is not "what is safe to lose" — it is "what costs while idle".**
The network skeleton stays: vpc, subnets, routes, firewall and both address
units. Those are nearly free to keep, expensive to rebuild by hand, and
destroying the address units would release the egress addresses external
services have allow-listed — the one thing here whose loss is visible to
other people.

The order matters and is the config's rather than terragrunt's. A cluster
holds load balancers that hold addresses; destroying an address first
leaves the load balancer stuck and the run half finished.

## What the trigger does and does not protect

The trailer is anchored to the start of a line, so a message that merely
*mentions* it does not match — a revert, a branch summary, a line of
documentation. That was verified against those cases rather than assumed.

**It is carried verbatim by a cherry-pick or a rebase.** Replaying an old
teardown commit onto `main` re-triggers the workflow. That cannot be fixed
in the trigger, so it is stated here rather than implied away.

Which is why the marker only *starts* the run:

- the units come from the config, never from the commit — a message that
  could name its own targets could name the VPC;
- the plan job runs under the **read-only** identity and publishes a
  destroy plan as an artifact;
- the destroy job runs under the environment carrying required reviewers.

The marker chooses. A human confirms, after reading the plan — and that
approval is what a replayed commit still has to get past.

## Bringing it back

Nothing special. The configs still say those units are enabled, so the next
`infra-plan` opens an ordinary deploy PR to rebuild them, with a plan to
review like any other.

There is deliberately no "restore" workflow. A second command would be a
second way for the repository and the cloud to disagree; this way the
disagreement is what the normal flow already reports.

## What it costs to come back

Not zero, and worth knowing before parking something:

- **A cluster takes minutes to create**, and its nodes join afterwards. On
  AWS they stay `NotReady` until Cilium is installed by Flux — that is the
  intended sequence, not a fault.
- **The proxy's address is stable.** It is reserved by
  `network/addresses/private`, which is not torn down, so the workload's
  route survives the proxy that answered on it.
- **The egress addresses are stable**, for the same reason. Nobody has to
  be told a new address to allow-list.
