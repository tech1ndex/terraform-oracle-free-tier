resource "random_integer" "this" {
  min = 0
  max = 255
}

resource "oci_core_vcn" "this" {
  compartment_id = var.compartment_id

  cidr_blocks  = [coalesce(var.cidr_block, "192.168.${random_integer.this.result}.0/24")]
  display_name = var.name
  dns_label    = "vcn"
}

resource "oci_core_internet_gateway" "this" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id

  display_name = oci_core_vcn.this.display_name
}

resource "oci_core_default_route_table" "this" {
  manage_default_resource_id = oci_core_vcn.this.default_route_table_id

  display_name = oci_core_vcn.this.display_name

  route_rules {
    network_entity_id = oci_core_internet_gateway.this.id

    description = "Default route"
    destination = "0.0.0.0/0"
  }
}

resource "oci_core_default_security_list" "this" {
  manage_default_resource_id = oci_core_vcn.this.default_security_list_id

  dynamic "ingress_security_rules" {
    for_each = [22, 80, 443]
    iterator = port
    content {
      protocol = local.protocol_number.tcp
      source   = "0.0.0.0/0"

      description = "SSH and HTTPS traffic from any origin"

      tcp_options {
        max = port.value
        min = port.value
      }
    }
  }

  dynamic "ingress_security_rules" {
    for_each = [51820]
    iterator = port
    content {
      protocol = local.protocol_number.udp
      source   = "0.0.0.0/0"

      description = "SSH and HTTPS traffic from any origin"

      udp_options {
        max = port.value
        min = port.value
      }
    }
  }

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"

    description = "All traffic to any destination"
  }
}

resource "oci_core_subnet" "this" {
  cidr_block     = oci_core_vcn.this.cidr_blocks.0
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id

  display_name = oci_core_vcn.this.display_name
  dns_label    = "subnet"
}

resource "oci_core_network_security_group" "this" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id

  display_name = oci_core_vcn.this.display_name
}

resource "oci_core_network_security_group_security_rule" "this" {
  direction                 = "INGRESS"
  network_security_group_id = oci_core_network_security_group.this.id
  protocol                  = local.protocol_number.icmp
  source                    = "0.0.0.0/0"
}

data "oci_identity_availability_domains" "this" {
  compartment_id = var.tenancy_ocid
}

data "oci_core_shapes" "this" {
  for_each = toset(data.oci_identity_availability_domains.this.availability_domains[*].name)

  compartment_id = var.tenancy_ocid

  availability_domain = each.key
}

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