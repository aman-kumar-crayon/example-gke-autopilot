# create VPC
resource "google_compute_network" "vpc" {
  name                    = "vpc1"
  auto_create_subnetworks = false
}

# Create Subnet
resource "google_compute_subnetwork" "subnet" {
  name          = "subnet1"
  region        = "asia-south2"
  network       = google_compute_network.vpc.name
  ip_cidr_range = "10.0.0.0/24"
}

# # Create Service Account
# resource "google_service_account" "mysa" {
#   account_id   = "mysa"
#   display_name = "Service Account for GKE nodes"
# }


# Create GKE cluster with 2 nodes in our custom VPC/Subnet
resource "google_container_cluster" "primary" {
  name                     = "my-gke-cluster"
  location                 = "asia-south2"
   enable_autopilot = true
  network                  = google_compute_network.vpc.name
  subnetwork               = google_compute_subnetwork.subnet.name
#  remove_default_node_pool = true                ## create the smallest possible default node pool and immediately delete it.
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
