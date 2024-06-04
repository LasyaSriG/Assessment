provider "google" {
  credentials = file("key.json")  # Path to your service account key file
  project     = "lasya-ganta-14"  # Replace with your GCP project ID
  region      = "us-central1"      # Change to your preferred region
}
 
resource "google_compute_network" "vpc_network" {
  name = "ansible-vpc"
}
 
resource "google_compute_subnetwork" "subnet" {
  name          = "ansible-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = "us-central1"
  network       = google_compute_network.vpc_network.id
}
 
resource "google_compute_firewall" "allow" {
  name    = "allow-http-https"
  network = google_compute_network.vpc_network.id
 
  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443", "8080"]
  }
 
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["http-server", "https-server", "ansible","jenkins"]
}
 
resource "google_compute_instance" "ansible_instance" {
  name         = "ansible-instance"
  machine_type = "e2-medium"
  zone         = "us-central1-a"
  tags         = ["jenkins"]
 
  boot_disk {
    initialize_params {
      image = "projects/ubuntu-os-pro-cloud/global/images/ubuntu-pro-2004-focal-v20210720"
    }
  }
 
  network_interface {
    network    = google_compute_network.vpc_network.id
    subnetwork = google_compute_subnetwork.subnet.id
 
    access_config {
      // Ephemeral public IP
    }
  }
 
  metadata_startup_script = <<-SCRIPT
    #!/bin/bash
sudo apt-get update
sudo apt-get install -y openssh-server ansible sshpass
sudo hostnamectl set-hostname master
echo 'root:${var.master_password}' | sudo chpasswd
sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sudo systemctl restart sshd
# Modify /etc/ansible/ansible.cfg
sudo sed -i '14s/^#//' /etc/ansible/ansible.cfg
sudo sed -i '22s/^#//' /etc/ansible/ansible.cfg

# Add slave instance to Ansible inventory
echo -e "[dev]\n${google_compute_instance.worker_instance.network_interface.0.network_ip
}" | sudo tee -a /etc/ansible/hosts

# Generate SSH key pair
ssh-keygen -t rsa -b 2048 -f /home/lasyasrilasya14/.ssh/id_rsa -N ""
 
 # Copy public key to slave instance
sshpass -p "${var.master_password}" ssh-copy-id -i /home/lasyasrilasya14/.ssh/id_rsa.pub -o StrictHostKeyChecking=no root@${google_compute_instance.worker_instance.network_interface.0.network_ip}
sshpass -p "ansible" ssh root@${google_compute_instance.worker_instance.network_interface.0.network_ip} "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys" < /home/lasyasrilasya14/.ssh/id_rsa.pub}

     ansible all -m ping --ask-pass -e "ansible_ssh_pass=${var.master_password}"
  
  SCRIPT
}


 
resource "google_compute_instance" "worker_instance" {
  name         = "worker-instance"
  machine_type = "e2-medium"
  zone         = "us-central1-a"
  tags         = ["jenkins"]
 
  boot_disk {
    initialize_params {
      image = "projects/ubuntu-os-pro-cloud/global/images/ubuntu-pro-2004-focal-v20210720"
    }
  }
 
  network_interface {
    network    = google_compute_network.vpc_network.id
    subnetwork = google_compute_subnetwork.subnet.id
 
    access_config {
      // Ephemeral public IP
    }
  }
 
  metadata_startup_script = <<-SCRIPT
    #!/bin/bash
    sudo apt-get update
    sudo apt-get install -y openssh-server
    sudo hostnamectl set-hostname worker
    echo 'root:${var.slave_password}' | sudo chpasswd
    sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
    sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
    # Modify /etc/ssh/sshd_configcd t 
    sudo sed -i '39s/^#//' /etc/ssh/sshd_config
    sudo sed -i '42s/^#//' /etc/ssh/sshd_config
    sudo systemctl restart sshd
    SCRIPT

}
 
output "master_instance_public_ip" {
  value = google_compute_instance.ansible_instance.network_interface.0.access_config.0.nat_ip
}
 
output "slave_instance_public_ip" {
  value = google_compute_instance.worker_instance.network_interface.0.access_config.0.nat_ip
}

