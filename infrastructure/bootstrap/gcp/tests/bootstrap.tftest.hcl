# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Chris <goabonga@pm.me>

# Offline — `mock_provider` intercepts every Google API call, so this needs
# no credentials and no network, the same contract as ../../modules/.
#
# The assertions are about the properties that make a bucket safe to hold
# state, not about terraform's ability to create one. Each has a failure
# mode that stays silent until it matters.

mock_provider "google" {}

variables {
  bucket   = "shomer-tfstate-test"
  project  = "shomer-test"
  location = "europe-west1"
}

run "versioning_is_enabled" {
  command = plan

  assert {
    condition     = one(google_storage_bucket.state.versioning).enabled
    error_message = "Without object versioning a corrupted state is unrecoverable."
  }
}

run "bucket_cannot_be_made_public" {
  command = plan

  assert {
    condition     = google_storage_bucket.state.uniform_bucket_level_access
    error_message = "Uniform access must be on, or a stray object ACL can widen access to the state."
  }

  assert {
    condition     = google_storage_bucket.state.public_access_prevention == "enforced"
    error_message = "Enforced prevention is the backstop for an IAM policy elsewhere granting allUsers."
  }
}

run "no_cmek_by_default" {
  command = plan

  assert {
    condition     = length(google_storage_bucket.state.encryption) == 0
    error_message = "With no key supplied the bucket must fall back to Google-managed keys, not to a half-configured encryption block."
  }
}

run "cmek_is_used_when_given" {
  command = plan

  variables {
    kms_key_name = "projects/shomer-test/locations/europe-west1/keyRings/r/cryptoKeys/k"
  }

  assert {
    condition     = one(google_storage_bucket.state.encryption).default_kms_key_name == "projects/shomer-test/locations/europe-west1/keyRings/r/cryptoKeys/k"
    error_message = "A CMEK was supplied and ignored — state would be encrypted with the wrong key."
  }
}

run "state_history_is_kept" {
  command = plan

  assert {
    condition = anytrue([
      for r in google_storage_bucket.state.lifecycle_rule :
      one(r.condition).days_since_noncurrent_time >= 30
      if one(r.action).type == "Delete"
    ])
    error_message = "State history shorter than 30 days is not an undo history — a bad apply is often noticed days later."
  }
}

run "destroy_is_not_armed_by_default" {
  command = plan

  assert {
    condition     = google_storage_bucket.state.force_destroy == false
    error_message = "force_destroy defaulting to true would let `terraform destroy` delete the only record of what exists."
  }
}
