
Ansible playbook to bootstrap kubernetes (work in progress)
================================================================

1.	Configure your inventory.
	Create file `~/.ansible.cfg` with the following content.

		[defaults]
		inventory = /home/user/.ansible-hosts.ini

	Create file `~/.ansible-hosts.ini'` with the following content.

		[k8s_nodes]
		k8s-1 ansible_host=192.168.56.101 ansible_user=user ansible_sudo_pass=123 ansible_python_interpreter=/usr/bin/python3
		k8s-2 ansible_host=192.168.56.102 ansible_user=user ansible_sudo_pass=123 ansible_python_interpreter=/usr/bin/python3

2.	Run entire kubernetes installation

		cd k8s-playbook
		ansible-playbook all.yml -e target_hosts=k8s_nodes

	Or run single role, e.g.:

		ansible-playbook run-role.yml -e target_hosts=k8s_nodes -e target_role=k8s-controllers

3.	Check etcd works

		ssh user@one-of-nodes
		sudo etcdctlwrap member list

Installing new etcd cluster
--------------------------------

	ansible-playbook run-role.yaml -e target_hosts=k8s_nodes -e target_role=etcd





Replacing failed etcd node
--------------------------------

Suppose node3 failed.

1.	ssh to node1 and remove failed node from cluster:

		sudo /usr/local/bin/etcdctlwrap member list
		sudo /usr/local/bin/etcdctlwrap member remove <node 3 id discovered in the output of previous command>

2.	reinstall whole cluster with `initial_cluster_state=existing` option
		
		ansible-playbook run-role.yaml -e target_hosts=k8s-nodes -e target_role=etcd -e initial_cluster_state=existing

3.	ssh to node1 and add new node:

		sudo /usr/local/bin/etcdctlwrap member add node3 --peer-urls=https://node3:2380







Upgrade to latest ansible
=============================

Ansible 2.5.1 not supported by this playbook. 
There is a bug which prevents priviledge escalation when using include_role.
Also argv parameter not supported by command module.
Ansible 2.7 and higher seems to work.

	sudo apt update
	sudo apt install software-properties-common
	sudo apt-add-repository --yes --update ppa:ansible/ansible
	sudo apt install ansible