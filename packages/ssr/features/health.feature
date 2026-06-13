# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

Feature: Liveness probe
  As an operator of shomer-ssr
  I want the service to answer its liveness probe with a stable
  contract so deployers can wire it into the Helm chart's readiness
  + liveness checks without parsing rendered HTML.

  Background:
    Given shomer-ssr is reachable at SHOMER_SSR_URL

  Scenario: /healthz reports ok with the running version
    When I GET "/healthz"
    Then the response status is 200
    And the JSON body has key "status" equal to "ok"
    And the JSON body has key "version" matching "^\d+\.\d+\.\d+$"
