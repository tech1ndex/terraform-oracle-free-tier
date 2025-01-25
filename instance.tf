data "cloudinit_config" "this" {
  for_each = local.user_data

  part {
    content = yamlencode(each.value)

    content_type = "text/cloud-config"
  }
}

data "oci_core_images" "this" {
  operating_system = "Canonical Ubuntu"
  compartment_id   = var.compartment_id
  shape            = local.shapes.micro
  sort_by          = "DISPLAYNAME"
  sort_order       = "DESC"
  state            = "available"
}

resource "oci_core_instance" "this" {
  count = 1

  availability_domain = local.availability_domain_micro
  compartment_id      = var.compartment_id
  shape               = local.shapes.micro


  display_name         = "${var.name}-${count.index + 1}"
  preserve_boot_volume = false

  metadata = {
    ssh_authorized_keys = local.ssh_public_key
    user_data           = data.cloudinit_config.this["this"].rendered
  }

  agent_config {
    are_all_plugins_disabled = true
    is_management_disabled   = true
    is_monitoring_disabled   = true
  }

  availability_config {
    is_live_migration_preferred = null
  }

  create_vnic_details {
    display_name   = "${var.name}-${count.index + 1}"
    hostname_label = "${var.name}-${count.index + 1}"
    nsg_ids        = [oci_core_network_security_group.this.id]
    subnet_id      = oci_core_subnet.this.id
  }

  source_details {
    source_id               = data.oci_core_images.this.images.0.id
    source_type             = "image"
    boot_volume_size_in_gbs = 50
  }

  lifecycle {
    ignore_changes = [source_details.0.source_id]
  }
}