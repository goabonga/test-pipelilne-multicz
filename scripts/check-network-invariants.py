#!/usr/bin/env python3

# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

"""Assert that the Kubernetes policies agree with the environment configs.

The egress design is enforced in two places that cannot see each other.
Terraform reads `infrastructure/configs/<env>/config.yaml`; the
NetworkPolicies under `gitops/` are static YAML applied by Flux. Both name
the proxy's subnet and the proxy's port, and nothing makes them agree.

THE FAILURE IS SILENT AND ONE-SIDED. Change the proxy subnet in a config
and terraform moves the subnet, the route, the NAT and the firewall rule in
one apply. The NetworkPolicy keeps the old range, applies cleanly, and
blocks every pod's egress — with no policy denial to read, because from the
pod's side the packet simply goes nowhere. The reverse is worse: widen the
range in the policy and pods reach hosts the firewall was written to
exclude.

This is the check for a hole this repository dug itself. The policies were
written with the ranges inlined because a NetworkPolicy has no way to
reference a value from elsewhere — that constraint is real, so the answer
is to verify the duplication rather than remove it.

Exits non-zero and names both sides. Run by the `validate` CI job.
"""

from __future__ import annotations

import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
CONFIGS = ROOT / "infrastructure" / "configs"
APPS = ROOT / "gitops" / "apps"


def _load(path: Path) -> dict:
    with path.open() as fh:
        return yaml.safe_load(fh)


def _docs(path: Path) -> list[dict]:
    with path.open() as fh:
        return [d for d in yaml.safe_load_all(fh) if d]


def check_environment(env: str) -> list[str]:
    """Return one message per disagreement between the config and the policies."""
    problems: list[str] = []

    config = _load(CONFIGS / env / "config.yaml")
    subnets = config["network"]["subnets"]

    egress = [v["cidr"] for v in subnets.values() if v["purpose"] == "egress"]
    if len(egress) != 1:
        # The modules already refuse this, but the message there is about
        # terraform. Said here, it explains why the policy check cannot run.
        return [f"{env}: expected exactly one egress subnet, found {len(egress)}"]
    proxy_cidr = egress[0]
    proxy_port = config["services"]["vms"]["proxy"]["port"]

    policy_path = APPS / env / "allow-egress-to-proxy.yaml"
    if not policy_path.exists():
        return [
            (
                f"{env}: {policy_path.relative_to(ROOT)} is missing. Without it "
                f"the deny floor blocks every pod's egress, including to the proxy."
            )
        ]

    for doc in _docs(policy_path):
        if doc.get("kind") != "NetworkPolicy":
            continue
        name = doc["metadata"]["name"]
        for rule in doc["spec"].get("egress", []):
            for to in rule.get("to", []):
                block = to.get("ipBlock")
                if block and block.get("cidr") != proxy_cidr:
                    problems.append(
                        f"{env}: {name} allows egress to {block['cidr']}, but the "
                        f"proxy subnet in config.yaml is {proxy_cidr}. The policy "
                        f"applies cleanly either way — too narrow blocks all "
                        f"egress with no denial to read, too wide reaches hosts "
                        f"the firewall excludes."
                    )
            for port in rule.get("ports", []):
                if port.get("port") != proxy_port:
                    problems.append(
                        f"{env}: {name} allows port {port.get('port')}, but Squid "
                        f"listens on {proxy_port} per config.yaml. Pods would "
                        f"reach the proxy subnet on a port nothing answers."
                    )

    return problems


def check_policies_are_narrowed() -> list[str]:
    """Every release must override the chart's permissive default.

    NetworkPolicy is additive: the deny floor in gitops/infrastructure does
    not override a permissive policy, it unions with it. The charts default
    to `ingress: [{}]` — allow from anywhere — so a release left at that
    default reinstates open ingress for its pod while the floor still reads
    as a deny-all.
    """
    problems: list[str] = []
    base = APPS / "base"

    for path in sorted(base.glob("*.yaml")):
        if path.name == "kustomization.yaml":
            continue
        for doc in _docs(path):
            if doc.get("kind") != "HelmRelease":
                continue
            name = doc["metadata"]["name"]
            values = doc["spec"].get("values") or {}
            np = values.get("networkPolicy")
            if np is None:
                problems.append(
                    f"{path.relative_to(ROOT)}: release '{name}' sets no "
                    f"networkPolicy values, so it keeps the chart's default of "
                    f"allow-from-anywhere — which unions with the deny floor and "
                    f"silently opts this pod out of it."
                )
                continue
            if np.get("ingress") == [{}]:
                problems.append(
                    f"{path.relative_to(ROOT)}: release '{name}' allows ingress "
                    f"from anywhere, which is the chart default written out. The "
                    f"deny floor cannot override it."
                )

    return problems


def main() -> int:
    problems: list[str] = []

    for env_dir in sorted(p for p in CONFIGS.iterdir() if p.is_dir()):
        problems += check_environment(env_dir.name)

    problems += check_policies_are_narrowed()

    if problems:
        print("Network policy does not agree with the environment configs:\n")
        for p in problems:
            print(f"  - {p}")
        print(
            "\nBoth sides describe the same boundary and neither can read the "
            "other, so the duplication is verified rather than removed."
        )
        return 1

    print("network invariants: policies agree with every environment config")
    return 0


if __name__ == "__main__":
    sys.exit(main())
