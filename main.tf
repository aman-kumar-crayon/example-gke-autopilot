variable "project_id" {}
variable "service_account" {}

# create VPC
resource "google_compute_network" "vpc" {
  name                    = "vpc1"
  auto_create_subnetworks = false
}

# Create Subnet
resource "google_compute_subnetwork" "subnet" {
  name          = "subnet1"
  region        = "europe-west3"
  network       = google_compute_network.vpc.name
  ip_cidr_range = "10.0.0.0/24"
depends_on = [google_compute_network.vpc]
}

resource "google_compute_router" "router" {
  name    = "cloud-router"
  region        = "europe-west3"
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "cloud-nat"
  router                             = google_compute_router.router.name
  region                             = google_compute_router.router.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
depends_on = [google_compute_router.router]
}


# # Create Service Account
# resource "google_service_account" "mysa" {
#   account_id   = "mysa"
#   display_name = "Service Account for GKE nodes"
# }

/*
# Create GKE cluster with 2 nodes in our custom VPC/Subnet
resource "google_container_cluster" "primary" {
  name                     = "my-gke-cluster"
  location                 = "europe-west3-a"
  #enable_autopilot = true
  network                  = google_compute_network.vpc.name
  subnetwork               = google_compute_subnetwork.subnet.name
  remove_default_node_pool = true                ## create the smallest possible default node pool and immediately delete it.
  # networking_mode          = "VPC_NATIVE" 
  initial_node_count       = 1
  
  private_cluster_config {
    enable_private_endpoint = true
    enable_private_nodes   = true 
    master_ipv4_cidr_block = "10.13.0.0/28"
  }
  ip_allocation_policy {
    cluster_ipv4_cidr_block  = "10.11.0.0/21"
    services_ipv4_cidr_block = "10.12.0.0/21"
  }
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "10.0.0.7/32"
      display_name = "net1"
    }

  }
depends_on = [ google_compute_subnetwork.subnet,google_compute_router_nat.nat ]
}

# Create managed node pool
resource "google_container_node_pool" "primary_nodes" {
  name       = google_container_cluster.primary.name
  location   = "europe-west3-a"
  cluster    = google_container_cluster.primary.name
  node_count = 1

  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]

    labels = {
      env = "dev"
    }

    machine_type = "n1-standard-1"
    preemptible  = false
    #service_account = google_service_account.mysa.email

    metadata = {
      disable-legacy-endpoints = "true"
    }
  }
}
*/


resource "google_container_cluster" "primary" {

  name     = "my-gke-cluster"
  location = "europe-west3"
  network                  = google_compute_network.vpc.name
  subnetwork               = google_compute_subnetwork.subnet.name
  initial_node_count = 1
  # Enabling autopilot for this cluster
  enable_autopilot = true

  ip_allocation_policy {
  }
       private_cluster_config {
           enable_private_endpoint = true
           enable_private_nodes    = true
           master_ipv4_cidr_block = "10.1.0.0/28"

           master_global_access_config {
              enabled = false 
            }
        }

master_authorized_networks_config {
cidr_blocks {

cidr_blocks = "10.0.0.7/32"
}
gcp_public_cidrs_access_enabled = false

}

depends_on = [ google_compute_subnetwork.subnet,google_compute_router_nat.nat ]
}

## Create jump host . We will allow this jump host to access GKE cluster. the ip of this jump host is already authorized to allowin the GKE cluster

resource "google_compute_address" "my_internal_ip_addr" {
  project      = var.project_id
  address_type = "INTERNAL"
  region       = "europe-west3"
  subnetwork   = "subnet1"
  name         = "my-ip"
  address      = "10.0.0.7"
  description  = "An internal IP address for my jump host"
depends_on = [google_compute_subnetwork.subnet]
}

resource "google_compute_instance" "proxy" {
  project      = var.project_id
  zone         = "europe-west3-a"
  name         = "proxy"
  machine_type = "e2-small"
  allow_stopping_for_update = true
  metadata_startup_script   = file("${path.module}/install_proxy.sh")
  boot_disk {
    initialize_params {
      image = "projects/ubuntu-os-cloud/global/images/ubuntu-2004-focal-v20231101"
    }
  }
  network_interface {
    network    = "vpc1"
    subnetwork = "subnet1" # Replace with a reference or self link to your subnet, in quotes
    network_ip         = google_compute_address.my_internal_ip_addr.address
  }
  service_account {
    email  = var.service_account
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }
depends_on = [ google_compute_subnetwork.subnet,google_compute_router_nat.nat ]
}


## Creare Firewall to access jump hist via iap


resource "google_compute_firewall" "rules" {
  project = var.project_id
  name    = "allow-ssh"
  network = "vpc1" # Replace with a reference or self link to your network, in quotes

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["35.235.240.0/20"]
depends_on = [ google_compute_subnetwork.subnet,google_compute_router_nat.nat ]
}



## Create IAP SSH permissions for your test instance

resource "google_project_iam_member" "project" {
  project = var.project_id
  role    = "roles/iap.tunnelResourceAccessor"
  member  = "serviceAccount:${var.service_account}"
}

# create cloud router for nat gateway
/*
resource "google_compute_router" "router" {
  project = var.project_id
  name    = "nat-router"
  network = "vpc1"
  region  = "europe-west3"
}

## Create Nat Gateway with module

module "cloud-nat" {
  source     = "terraform-google-modules/cloud-nat/google"
  version    = "~> 1.2"
  project_id = var.project_id
  region     = "europe-west3"
  router     = google_compute_router.router.name
  name       = "nat-config"

}
*/

############Output############################################
output "kubernetes_cluster_host" {
  value       = google_container_cluster.primary.endpoint
  description = "GKE Cluster Host"
}

output "kubernetes_cluster_name" {
  value       = google_container_cluster.primary.name
  description = "GKE Cluster Name"
}


############ proxy ############
resource "google_compute_firewall" "allow-proxy" {
  name          = "allow-proxy"
  description   = "Allow access to the proxy"
  network       = google_compute_network.vpc.name
  direction     = "INGRESS"
  source_ranges = ["10.0.0.0/8"] # This could be more limited
  allow {
    protocol = "tcp"
    ports    = [3128]
  }
  target_tags = ["proxy"]
depends_on = [google_compute_subnetwork.subnet]
}

resource "google_dns_managed_zone" "example_internal" {
  private_visibility_config {
    networks {
      network_url = google_compute_network.vpc.self_link
    }
  }
  visibility = "private"
  dns_name   = "example.internal."
  name       = "example-internal"
depends_on = [google_compute_network.vpc]
}

resource "google_dns_record_set" "proxy_internal" {
  managed_zone = google_dns_managed_zone.example_internal.name
  name         = "proxy.example.internal."
  type         = "A"
  rrdatas      = [google_compute_instance.proxy.network_interface.0.network_ip]
depends_on = [google_compute_network.vpc]
}

##############

### Create a private service peering address range ###
resource "google_compute_global_address" "psc-range" {
  name          = "private-service-ip-alloc"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 24
  address = "192.168.0.0"
  network       = google_compute_network.vpc.name
depends_on = [google_compute_subnetwork.subnet]
}
### Create the service peering connection ###
resource "google_service_networking_connection" "psc" {
  network                 = google_compute_network.vpc.name
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.psc-range.name]
depends_on = [google_compute_network.vpc]
}
### Enable DNS resolving for example.internal in service networks###
resource "google_service_networking_peered_dns_domain" "dns-peering" {
  name       = "internal-dns-peering"
  network    = google_compute_network.vpc.name
  dns_suffix = "example.internal."
depends_on = [google_compute_network.vpc]
}

