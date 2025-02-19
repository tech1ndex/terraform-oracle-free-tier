locals {
  ssh_public_key = var.ssh_public_key
  protocol_number = {
    icmp   = 1
    icmpv6 = 58
    tcp    = 6
    udp    = 17
  }

  shapes = {
    flex : "VM.Standard.A1.Flex",
    micro : "VM.Standard.E2.1.Micro",
  }

  availability_domain_micro = one(
    [
      for m in data.oci_core_shapes.this :
      m.availability_domain
      if contains(m.shapes[*].name, local.shapes.micro)
    ]
  )

  user_data = {
    this : {
      runcmd : ["apt-get remove --quiet --assume-yes --purge apparmor"]
    },
  }
}
