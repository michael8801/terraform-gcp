resource "google_compute_subnetwork" "petclinic-subnet-tf-eu-west1" {
  name          = "petclinic-subnet-tf-eu-west1"
  ip_cidr_range = "10.24.5.0/24"
  region        = var.region
  network       = google_compute_network.petclinic-vpc-tf.id        #implicit dependency

}

resource "google_compute_network" "petclinic-vpc-tf" {
  name                    = "petclinic-vpc-tf"
  auto_create_subnetworks = false             #When set to true, the network is created in "auto subnet mode". When set to false, the network is created in "custom subnet mode".
  mtu                     = 1460
}

resource "google_compute_firewall" "ssh-rule" {
  project       = var.project
  name          = "petclinic-allow-ssh-tf"
  network       = google_compute_network.petclinic-vpc-tf.self_link
  description   = "Creates firewall rule with ssh tag"
  direction     = "INGRESS"
  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }


  target_tags = ["ssh"]
}

resource "google_compute_firewall" "http-rule" {
  project       = var.project
  name          = "petclinic-allow-http-tf"
  network       = google_compute_network.petclinic-vpc-tf.self_link
  description   = "Creates firewall rule with web tag"
  direction     = "INGRESS"
  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }


  target_tags = ["web"]
}


resource "google_compute_address" "static" {
  name = "petclinic-public-ip-tf"
}

data "google_service_account" "petclinic-sa" {
  account_id = var.account_id
}


resource "google_compute_instance" "petclinic-app-tf" {
  name         = "petclinic-app-tf"
  machine_type = var.machine_type
  zone         = var.zone

  tags = ["ssh", "web"]

  boot_disk {
    initialize_params {
      image = var.image
    
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.petclinic-subnet-tf-eu-west1.self_link

    access_config {
      // Ephemeral public IP
       nat_ip = google_compute_address.static.address
    }
  }

  service_account {
    email = data.google_service_account.petclinic-sa.email
    scopes = ["cloud-platform"]
  }

}


resource "google_compute_global_address" "private_ip_address" {
  name         = "private-ip-block"
  purpose      = "VPC_PEERING"
  address_type = "INTERNAL"
  ip_version   = "IPV4"
  prefix_length = 20
  network       = google_compute_network.petclinic-vpc-tf.self_link
}

resource "google_service_networking_connection" "private_vpc_connection" {
  

  network                 = google_compute_network.petclinic-vpc-tf.self_link
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}

resource "random_id" "db_name_suffix" {
  byte_length = 4
}

resource "google_sql_database_instance" "petclinic-db-instance" {
name = "petclinic-db-tf-${random_id.db_name_suffix.hex}"
database_version = var.db-version
region = var.region
depends_on = [google_service_networking_connection.private_vpc_connection]
deletion_protection = false

  settings {
    tier = "db-f1-micro"
    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.petclinic-vpc-tf.id
    }
  }

}
resource "google_sql_database" "petclinic-db" {
name = var.name
instance = google_sql_database_instance.petclinic-db-instance.name
charset = "utf8"
collation = "utf8_general_ci"

}
resource "google_sql_user" "users" {
name = var.name
instance = google_sql_database_instance.petclinic-db-instance.name
host = "%"
password = "petclinic"
}

