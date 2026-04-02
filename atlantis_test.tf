locals {
  # Test marker to trigger Atlantis plan on PR without changing infrastructure.
  atlantis_pr_test_marker = "test-atlantis-webhook"
}

locals {
  atlantis_pr_test_marker_2 = "trigger-1775112496"
}

locals {
  pr_manual_test_marker = "manual-1775114359"
}
