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