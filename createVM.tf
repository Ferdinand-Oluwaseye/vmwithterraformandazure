
variable "prefix" {
	default = "myvm"
}

resource "azurerm_resource_group" "main" {
	name = "${var.prefix}-resources"
	location = "uksouth"

}

resource "azurerm_virtual_network" "main" {
	name = "${var.prefix}-network"
	address_space = ["10.0.0.0/16"]
	location = "${azurerm_resource_group.main.location}"
	resource_group_name = "${azurerm_resource_group.main.name}"
}

resource "azurerm_subnet" "internal" {
	name = "internal"	
	resource_group_name = "${azurerm_resource_group.main.name}"
	virtual_network_name = "${azurerm_virtual_network.main.name}"
	address_prefix = "10.0.2.0/24"
}


resource "azurerm_public_ip" "main" {
	name = "${var.prefix}-publicip"
	location = "${azurerm_resource_group.main.location}"	
	resource_group_name = "${azurerm_resource_group.main.name}"
	allocation_method = "Dynamic"
	domain_name_label = "ferd-${formatdate("DDMMYYhhmmss", timestamp())}"

}

resource "azurerm_network_security_group" "main" {
	name = "${var.prefix}-nsg"
	location = "${azurerm_resource_group.main.location}"
	resource_group_name = "${azurerm_resource_group.main.name}"
	
	security_rule {
		name = "SSH"
		priority = "400"
		direction = "Inbound"
		access = "Allow"
		protocol = "Tcp"
		source_port_range = "*"
		destination_port_range = "22"
		source_address_prefix = "*"
		destination_address_prefix = "*"
	}

	security_rule {
                name = "Jenkins"
                priority = "500"
                direction = "Inbound"
                access = "Allow"
                protocol = "Tcp"
                source_port_range = "*"
                destination_port_range = "8080"
                source_address_prefix = "*"
                destination_address_prefix = "*"
        }
}



resource "azurerm_network_interface" "main" {
	name = "${var.prefix}-nic"
	location = "${azurerm_resource_group.main.location}"
	resource_group_name = "${azurerm_resource_group.main.name}"
	network_security_group_id = "${azurerm_network_security_group.main.id}"
	
	ip_configuration {
		name = "testconfiguration1"
		subnet_id = "${azurerm_subnet.internal.id}"
		private_ip_address_allocation = "Dynamic"
		public_ip_address_id = "${azurerm_public_ip.main.id}"
		
	}
}

resource "azurerm_virtual_machine" "main" {
	name = "${var.prefix}-vm"
	location = "${azurerm_resource_group.main.location}"
	resource_group_name = "${azurerm_resource_group.main.name}"
	network_interface_ids = ["${azurerm_network_interface.main.id}"]
	vm_size = "Standard_DS1_v2"


	storage_image_reference {
		publisher = "Canonical"
		offer = "UbuntuServer"
		sku = "16.04-LTS"
		version = "latest"
	}

	storage_os_disk {
		name = "myosdisk1"
		caching = "ReadWrite"
		create_option = "FromImage"
		managed_disk_type = "Standard_LRS"

	}

	os_profile {
		computer_name = "hostname"
		admin_username = "Seye"
		admin_password = "Password1234"
	}

	os_profile_linux_config {
		disable_password_authentication = true
		ssh_keys {
			path = "/home/Seye/.ssh/authorized_keys"
			key_data = "${file("/home/ferdinand/.ssh/id_rsa.pub")}"		
		}
	}

	tags = {
		environment = "staging"
	}

	provisioner "remote-exec"{
		inline = [
			"sudo apt update",
			"sudo apt install -y jq",
			"mkdir myrepo", 
			"cd myrepo", 
			"git clone https://github.com/Ferdinand-Oluwaseye/jenkins-scripts", 
			"cd jenkins-scripts", "./jenkinsInstall.sh"
			]

		connection {
			type = "ssh"
			user = "Seye"
			private_key = file("/home/ferdinand/.ssh/id_rsa")
			host = "${azurerm_public_ip.main.fqdn}"
		}
	}	
}

