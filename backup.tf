resource "oci_core_volume_backup_policy" "this" {
  compartment_id = var.compartment_id

  display_name = "Daily"

  schedules {
    backup_type       = "INCREMENTAL"
    hour_of_day       = 0
    offset_type       = "STRUCTURED"
    period            = "ONE_DAY"
    retention_seconds = 86400
    time_zone         = "REGIONAL_DATA_CENTER_TIME"
  }
}

resource "oci_core_volume_backup_policy_assignment" "this" {
  asset_id  = oci_core_instance.this.0.boot_volume_id
  policy_id = oci_core_volume_backup_policy.this.id
}