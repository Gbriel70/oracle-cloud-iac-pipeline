# ============================================================================
# OCI Networking - VCN, Subnets, Security Groups
# Conceito: Isolar redes assim como fizemos com Docker (4 redes isoladas)
# ============================================================================

# ============================================================================
# VIRTUAL CLOUD NETWORK (VCN) - Equivalente a um VPC na AWS
# ============================================================================

resource "oci_core_vcn" "main" {
  compartment_id = var.compartment_id
  cidr_block     = var.vcn_cidr
  display_name   = "${var.project_name}-vcn-${var.environment}"
  dns_label      = "mainvcn"

  freeform_tags = merge(
    local.common_tags,
    { Name = "${var.project_name}-vcn" }
  )
}

# ============================================================================
# INTERNET GATEWAY - Permite comunicação com a internet
# ============================================================================

resource "oci_core_internet_gateway" "main" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.project_name}-igw-${var.environment}"
  enabled        = true

  freeform_tags = local.common_tags
}

resource "oci_core_nat_gateway" "main" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.project_name}-nat-${var.environment}"
  block_traffic  = false

  freeform_tags = local.common_tags
}

# ============================================================================
# ROUTE TABLES - Define para onde o tráfego deve ir
# ============================================================================

# Route table para SUBNET PÚBLICA (Nginx - acesso à internet)
resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.project_name}-rt-public-${var.environment}"

  # Regra: tráfego com destino 0.0.0.0/0 (todo mundo) vai para Internet Gateway
  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.main.id
  }

  freeform_tags = local.common_tags
}

resource "oci_core_route_table" "private" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.project_name}-rt-private-${var.environment}"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.main.id
  }

  freeform_tags = local.common_tags
}

# ============================================================================
# SUBNETS
# ============================================================================

# SUBNET PÚBLICA - Nginx (tem acesso direto à internet)
resource "oci_core_subnet" "public" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  cidr_block     = var.public_subnet_cidr
  display_name   = "${var.project_name}-subnet-public-${var.environment}"
  dns_label      = "public"

  # Associa com a route table pública
  route_table_id = oci_core_route_table.public.id

  freeform_tags = merge(
    local.common_tags,
    { Name = "public-subnet", Tier = "public" }
  )
}

# SUBNET PRIVADA - Database (sem acesso direto à internet)
resource "oci_core_subnet" "private" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  cidr_block     = var.private_subnet_cidr
  display_name   = "${var.project_name}-subnet-private-${var.environment}"
  dns_label      = "private"

  route_table_id             = oci_core_route_table.private.id
  prohibit_public_ip_on_vnic = true

  freeform_tags = merge(
    local.common_tags,
    { Name = "private-subnet", Tier = "private" }
  )
}

# ============================================================================
# NETWORK SECURITY GROUPS (NSGs) - Firewall a nível de VM
# Equivalente aos Security Groups da AWS ou Firewall Rules
# ============================================================================

# NSG para BASTION (SSH)
resource "oci_core_network_security_group" "bastion" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.project_name}-nsg-bastion-${var.environment}"

  freeform_tags = local.common_tags
}

# Regra de entrada: SSH do seu IP
resource "oci_core_network_security_group_security_rule" "bastion_ssh_in" {
  network_security_group_id = oci_core_network_security_group.bastion.id

  direction   = "INGRESS"
  protocol    = "6" # TCP
  source      = var.allowed_ssh_cidrs[0]
  source_type = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }

  description = "SSH from allowed CIDR"
}

# Regra de saída: Bastion pode se comunicar com qualquer lugar (padrão)
resource "oci_core_network_security_group_security_rule" "bastion_egress" {
  network_security_group_id = oci_core_network_security_group.bastion.id

  direction   = "EGRESS"
  protocol    = "all"
  destination = "0.0.0.0/0"
}

# ============================================================================
# NSG para KUBERNETES NODES (comunicação interna + ingress)
# ============================================================================

resource "oci_core_network_security_group" "kubernetes" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.project_name}-nsg-k8s-${var.environment}"

  freeform_tags = local.common_tags
}

# Regra: HTTP (80)
resource "oci_core_network_security_group_security_rule" "k8s_http" {
  network_security_group_id = oci_core_network_security_group.kubernetes.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = "0.0.0.0/0"
  tcp_options {
    destination_port_range {
      min = 80
      max = 80
    }
  }
  description = "HTTP traffic (Nginx)"
}

# Regra: HTTPS (443)
resource "oci_core_network_security_group_security_rule" "k8s_https" {
  network_security_group_id = oci_core_network_security_group.kubernetes.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = "0.0.0.0/0"
  tcp_options {
    destination_port_range {
      min = 443
      max = 443
    }
  }
  description = "HTTPS traffic"
}

# Regra: SSH apenas do Bastion
resource "oci_core_network_security_group_security_rule" "k8s_ssh_from_bastion" {
  network_security_group_id = oci_core_network_security_group.kubernetes.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = oci_core_network_security_group.bastion.id
  source_type               = "NETWORK_SECURITY_GROUP"
  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }
  description = "SSH from Bastion only"
}

# Regra: Kubelet API (6443)
resource "oci_core_network_security_group_security_rule" "k8s_api" {
  network_security_group_id = oci_core_network_security_group.kubernetes.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = "10.0.0.0/16" # Apenas da VCN
  tcp_options {
    destination_port_range {
      min = 6443
      max = 6443
    }
  }
  description = "Kubernetes API"
}

# Regra: Tráfego entre K8s nodes
resource "oci_core_network_security_group_security_rule" "k8s_internal" {
  network_security_group_id = oci_core_network_security_group.kubernetes.id
  direction                 = "INGRESS"
  protocol                  = "all"
  source                    = oci_core_network_security_group.kubernetes.id
  source_type               = "NETWORK_SECURITY_GROUP"
  description               = "Internal K8s communication"
}

# Regra de saída: K8s pode acessar qualquer lugar
resource "oci_core_network_security_group_security_rule" "k8s_egress" {
  network_security_group_id = oci_core_network_security_group.kubernetes.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
  description               = "Outbound traffic"
}

# ============================================================================
# OUTPUTS - IPs e configurações necessárias
# ============================================================================

output "vcn_cidr" {
  description = "CIDR da VCN"
  value       = oci_core_vcn.main.cidr_block
}

output "public_subnet_cidr" {
  description = "CIDR da subnet pública"
  value       = oci_core_subnet.public.cidr_block
}

output "private_subnet_cidr" {
  description = "CIDR da subnet privada"
  value       = oci_core_subnet.private.cidr_block
}

# ⚠️ Private subnet output removido - Usando apenas subnet pública (Always Free)
