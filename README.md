
Ansible playbook to bootstrap kubernetes (work in progress)
================================================================


Install kubernetes
-----------------------

1.	Configure your inventory.
	Ensure file `~/.ansible.cfg` has content like the following.

		[defaults]
		inventory = /home/user/.ansible-hosts.ini

	Create file `~/.ansible-hosts.ini'` with content like the following.

		[etcd]
		k8s-1 ansible_host=192.168.56.101 ansible_user=user ansible_sudo_pass=123 ansible_python_interpreter=/usr/bin/python3 internal_ip_address=192.168.56.101
		k8s-2 ansible_host=192.168.56.102 ansible_user=user ansible_sudo_pass=123 ansible_python_interpreter=/usr/bin/python3 internal_ip_address=192.168.56.102

		[k8s_controllers]
		k8s-3 ansible_host=192.168.56.103 ansible_user=user ansible_sudo_pass=123 ansible_python_interpreter=/usr/bin/python3 internal_ip_address=192.168.56.103
		k8s-4 ansible_host=192.168.56.104 ansible_user=user ansible_sudo_pass=123 ansible_python_interpreter=/usr/bin/python3 internal_ip_address=192.168.56.104

		[k8s_workers]
		k8s-5 ansible_host=192.168.56.105 ansible_user=user ansible_sudo_pass=123 ansible_python_interpreter=/usr/bin/python3 internal_ip_address=192.168.56.105
		k8s-6 ansible_host=192.168.56.106 ansible_user=user ansible_sudo_pass=123 ansible_python_interpreter=/usr/bin/python3 internal_ip_address=192.168.56.106

2.	Install etcd

		ansible-playbook run-role.yml -e role_name=etcd -e host_pattern=etcd

	Check etcd works

		ssh user@one-of-etcd-nodes
		sudo etcdctlwrap member list

3.	Install kubernetes controllers, given etcd and workers hosts are known

		ansible-playbook run-role.yml -e role_name=k8s-controllers -e host_pattern=k8s_controllers -e etcd_hosts=etcd -e k8s_worker_hosts=k8s_workers

4.	Install kubernetes controllers, given etcd and workers hosts are known

		ansible-playbook run-role.yml -e role_name=k8s-workers -e host_pattern=k8s_workers -e k8s_controller_hosts=k8s_controllers


2.	Run entire kubernetes installation

		cd k8s-playbook
		ansible-playbook all.yml -e play_hosts=k8s

	Or run single role, e.g.:

		ansible-playbook run-role.yml -e play_hosts=k8s -e play_role=k8s-controllers -e etcd_hosts=etcd_hosts



todo




	

Smoke test
---------------

	ssh user@one-of-k8s-controllers
	kubectl create deployment nginx --image=nginx
	sleep 3
	kubectl get pods -l app=nginx
	POD_NAME=$(kubectl get pods -l app=nginx -o jsonpath="{.items[0].metadata.name}")	
	kubectl port-forward $POD_NAME 8080:80
	curl --head http://127.0.0.1:8080




Replacing failed etcd node
--------------------------------

Suppose node3 failed.

1.	ssh to node1 and remove failed node from cluster:

		sudo /usr/local/bin/etcdctlwrap member list
		sudo /usr/local/bin/etcdctlwrap member remove <node 3 id discovered in the output of previous command>

2.	reinstall whole cluster with `initial_cluster_state=existing` option
		
		ansible-playbook run-role.yaml -e role_name=etcd -e host_pattern=etcd -e initial_cluster_state=existing

3.	ssh to node1 and add new node:

		sudo /usr/local/bin/etcdctlwrap member add node3 --peer-urls=https://node3:2380







Upgrade to latest ansible
=============================

Ansible 2.5.1 not supported by this playbook. 
There is a bug which prevents priviledge escalation when using include_role.
Also argv parameter not supported by command module.
Ansible 2.7 and higher seems to work.
On ubuntu upgrade ansible with the following commands

	sudo apt update
	sudo apt install software-properties-common
	sudo apt-add-repository --yes --update ppa:ansible/ansible
	sudo apt install ansible