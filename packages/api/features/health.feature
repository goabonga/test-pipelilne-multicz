# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

Feature: Liveness and discovery surface
  As an operator of shomer-api
  I want the service to answer its liveness probe and publish its
  OIDC discovery document so deployers can wire it into a load
  balancer and OIDC clients can locate the OAuth2 endpoints.

  Background:
    Given shomer-api is reachable at SHOMER_API_URL

  Scenario: /healthz reports ok with the running version
    When I GET "/healthz"
    Then the response status is 200
    And the JSON body has key "status" equal to "ok"
    And the JSON body has key "version" matching "^\d+\.\d+\.\d+$"

  Scenario: OIDC discovery document advertises the OAuth2 endpoints
    When I GET "/.well-known/openid-configuration"
    Then the response status is 200
    And the JSON body has key "issuer"
    And the JSON body has key "authorization_endpoint"
    And the JSON body has key "token_endpoint"
    And the JSON body has key "jwks_uri"
    And the JSON body has key "response_types_supported" containing "code"
    And the JSON body has key "grant_types_supported" containing "authorization_code"
