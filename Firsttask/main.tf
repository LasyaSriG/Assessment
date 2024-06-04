provider "google" {
  project     = "lasya-ganta-14"
  region      = "us-east1"
  credentials = file("keys.json")
}
 
resource "google_compute_network" "network" {
  name                    = "jenkins-network"
  auto_create_subnetworks = false
}
 
resource "google_compute_subnetwork" "subnet" {
  name          = "jenkins-subnet"
  region        = "us-east1"
  network       = google_compute_network.network.self_link
  ip_cidr_range = "10.0.1.0/24"
}
 
resource "google_compute_firewall" "firewall" {
  name    = "jenkins-firewall"
  network = google_compute_network.network.self_link
 
  allow {
    protocol = "tcp"
    ports    = ["8080", "80", "443", "22"]
  }
 
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["jenkins"]
}
 
resource "google_compute_instance" "jenkins_instance" {
  name         = "jenkins-server"
  machine_type = "e2-medium"
  zone         = "us-east1-d"
 
  boot_disk {
    auto_delete = true
 
    initialize_params {
      image = "projects/ubuntu-os-cloud/global/images/ubuntu-2004-focal-v20240519"
      size  = 10
      type  = "pd-standard"
    }
  }
 
  network_interface {
    network    = google_compute_network.network.self_link
    subnetwork = google_compute_subnetwork.subnet.self_link
    access_config {
      network_tier = "PREMIUM"
    }
  }
 
  metadata_startup_script = <<-EOF
    #!/bin/bash
    # STEP:1 - Install Java latest version
    sudo apt-get update
    sudo apt install default-jdk -y
   
    # STEP:2 - Install Git
    sudo apt install git -y
   
    # STEP:3 - Install Jenkins
    sudo curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
    echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/ | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
    sudo apt-get update
    sudo apt-get install jenkins -y
 
    # STEP:4 - Install Maven
    wget https://apache.osuosl.org/maven/maven-3/3.9.5/binaries/apache-maven-3.9.5-bin.tar.gz
    tar xzvf apache-maven-3.9.5-bin.tar.gz
    sudo mv apache-maven-3.9.5 /opt
    echo 'export M2_HOME=/opt/apache-maven-3.9.5' >> ~/.bashrc
    echo 'export PATH=$M2_HOME/bin:$PATH' >> ~/.bashrc
    source ~/.bashrc
 
    # STEP:5 - Install Ansible
    sudo apt-get update
    sudo apt-get install -y software-properties-common
    sudo add-apt-repository --yes --update ppa:ansible/ansible
    sudo apt-get install -y ansible
  EOF
 
  service_account {
    email  = "default"
    scopes = [
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write",
      "https://www.googleapis.com/auth/service.management.readonly",
      "https://www.googleapis.com/auth/servicecontrol",
      "https://www.googleapis.com/auth/trace.append"
    ]
  }
 
  tags = ["http-server", "https-server", "jenkins"]
 
  shielded_instance_config {
    enable_integrity_monitoring = true
    enable_secure_boot          = false
    enable_vtpm                 = true
  }
 
  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
    preemptible         = false
  }
}
 
output "instance_ip" {
  value = google_compute_instance.jenkins_instance.network_interface[0].access_config[0].nat_ip
}
 
