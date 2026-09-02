# ============================================================================
# OCI Compute - Instâncias (VMs) para Bastion + Kubernetes
# ============================================================================

# ============================================================================
# BASTION HOST - VM intermediária para SSH seguro
# ============================================================================

resource "oci_core_instance" "bastion" {
  count               = var.enable_bastion ? 1 : 0
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_id
  display_name        = "${var.project_name}-bastion-${var.environment}"

  shape = local.instance_shapes[local.environment_name]

  shape_config {
    ocpus         = local.instance_ocpus[local.environment_name]
    memory_in_gbs = local.instance_memory[local.environment_name]
  }

  source_details {
    source_type             = "IMAGE"
    source_id               = local.resolved_image_ocid
    boot_volume_size_in_gbs = 50
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public.id
    nsg_ids          = [oci_core_network_security_group.bastion.id]
    assign_public_ip = true
    hostname_label   = "${var.project_name}-bastion"
  }

  metadata = {
    ssh_authorized_keys = file(var.ssh_public_key_path)
  }

  preserve_boot_volume = false

  lifecycle {
    ignore_changes = [source_details]
  }

  freeform_tags = merge(
    local.common_tags,
    { Name = "bastion-host", Role = "bastion" }
  )
}

# ============================================================================
# KUBERNETES NODES - VMs para cluster K8s
# ============================================================================

resource "oci_core_instance" "kubernetes_node" {
  count               = var.kubernetes_node_count
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_id
  display_name        = "${var.instance_display_name}-${count.index}"

  shape = local.instance_shapes[local.environment_name]

  shape_config {
    ocpus         = local.instance_ocpus[local.environment_name]
    memory_in_gbs = local.instance_memory[local.environment_name]
  }

  source_details {
    source_type             = "IMAGE"
    source_id               = local.resolved_image_ocid
    boot_volume_size_in_gbs = 100
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public.id
    nsg_ids          = [oci_core_network_security_group.kubernetes.id]
    assign_public_ip = true
    hostname_label   = "${var.instance_display_name}-${count.index}"
  }

  metadata = {
    ssh_authorized_keys = file(var.ssh_public_key_path)
  }

  preserve_boot_volume = false

  freeform_tags = merge(
    local.common_tags,
    {
      Name      = "k8s-node-${count.index}"
      Role      = "kubernetes"
      NodeIndex = count.index
    }
  )
}

# ============================================================================
# OUTPUTS - IPs e informações das instâncias
# ============================================================================

output "bastion_public_ip" {
  description = "IP público do Bastion"
  value       = var.enable_bastion ? oci_core_instance.bastion[0].public_ip : null
}

output "bastion_private_ip" {
  description = "IP privado do Bastion"
  value       = var.enable_bastion ? oci_core_instance.bastion[0].private_ip : null
}

output "kubernetes_node_public_ips" {
  description = "IPs públicos dos nós Kubernetes"
  value       = oci_core_instance.kubernetes_node[*].public_ip
}

output "kubernetes_node_private_ips" {
  description = "IPs privados dos nós Kubernetes"
  value       = oci_core_instance.kubernetes_node[*].private_ip
}

output "ssh_bastion_command" {
  description = "Comando para SSH no Bastion"
  value       = var.enable_bastion ? "ssh -i ~/.ssh/id_rsa ubuntu@${oci_core_instance.bastion[0].public_ip}" : null
}

output "ssh_k8s_node_command" {
  description = "Comando para SSH em nó K8s via Bastion"
  value       = (var.enable_bastion && var.kubernetes_node_count > 0) ? "ssh -i ~/.ssh/id_rsa -J ubuntu@${oci_core_instance.bastion[0].public_ip} ubuntu@${oci_core_instance.kubernetes_node[0].private_ip}" : null
}
