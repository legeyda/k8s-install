
Ansible playbook to bootstrap kubernetes (work in progress)
================================================================

For now etcd bootstraping is working.


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

Ansible 2.5.1 has as bug which prevents priviledge escalation when using include_role.
It was fixed in 2.7

	sudo apt update
	sudo apt install software-properties-common
	sudo apt-add-repository --yes --update ppa:ansible/ansible
	sudo apt install ansible