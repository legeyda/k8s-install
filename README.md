
Ansible playbook to bootstrap kubernetes (work in progress)
================================================================


Install kubernetes
-----------------------

1.	Configure your inventory.
	Ensure file `~/.ansible.cfg` has content like the following.

		[defaults]
		inventory = /home/user/.ansible-hosts.ini

	Create file `~/.ansible-hosts.ini` with content like the following.

		[etcd]
		k8s-1 internal_ip_address=192.168.56.101
		k8s-2 internal_ip_address=192.168.56.102

		[k8s_controllers]
		k8s-3 internal_ip_address=192.168.56.103
		k8s-4 internal_ip_address=192.168.56.104

		[k8s_workers]
		k8s-5 internal_ip_address=192.168.56.105
		k8s-6 internal_ip_address=192.168.56.106
	
	If any host have multiple ip addresses, use `internal_ip_address` variable
	to specify which one is for communication between hosts inside cluster.


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



Quick install on thee nodes
---------------------------------

	ansible-playbook --become run-role.yml -e role_name=etcd -e host_pattern=k8s-1,k8s-2 \
	&& ansible-playbook --become run-role.yml -e role_name=k8s-controllers -e host_pattern=k8s-2,k8s-3 -e etcd_hosts=k8s-1,k8s-2 -e k8s_worker_hosts=k8s-1,k8s-3 \
	&& ansible-playbook --become run-role.yml -e role_name=k8s-workers -e host_pattern=k8s-1,k8s-3 -e k8s_controller_hosts=k8s-2,k8s-3




Smoke test (from kubernetes the hard way)
-----------------------------------------------

	ssh user@one-of-k8s-controllers
	kubectl create deployment nginx --image=nginx
	sleep 3
	kubectl get pods -l app=nginx
	POD_NAME=$(kubectl get pods -l app=nginx -o jsonpath="{.items[0].metadata.name}")	
	kubectl port-forward $POD_NAME 8080:80
	curl --head http://127.0.0.1:8080



Working with etcd node failures
----------------------------------

1.	Configure etcd cluster hosts in `~/.ansible-hosts.ini`.

		[test_etcd_v1]
		k8s-1 internal_ip_address=192.168.56.101 etcd_node_name=etcd-a
		k8s-2 internal_ip_address=192.168.56.102 etcd_node_name=etcd-b
		k8s-3 internal_ip_address=192.168.56.103 etcd_node_name=etcd-c

2.	Install etcd on initial cluster.

		ansible-playbook run-role.yml -e role_name=etcd -e host_pattern=test_etcd_v1

3.	Put key to etcd cluster.

		$ ssh user@192.168.56.102
		$ sudo etcdctlwrap put test-key 'test value, hello from k8s-2'

	Check value is replicated among other hosts.

		$ ssh user@192.168.56.101
		$ sudo etcdctlwrap get test-key
		test-key
		test value, hello from k8s-2

4.	Suppose, node `etcd-b` has failed. Shut down host `192.168.56.102`.

5.	Check value is survived, since replicated among two other nodes.

		$ ssh user@192.168.56.101
		$ sudo etcdctlwrap get test-key
		test-key
		test value, hello from k8s-2

6.	Configure new set of hosts.
	Let failed second host be replaced with new one.

		[test_etcd_v2]
		k8s-1 internal_ip_address=192.168.56.101 etcd_node_name=etcd-a
		k8s-4 internal_ip_address=192.168.56.104 etcd_node_name=etcd-b
		k8s-3 internal_ip_address=192.168.56.103 etcd_node_name=etcd-c

7.	Reinstall new version of cluster with `initial_cluster_state=existing` option
		
		ansible-playbook run-role.yml -e role_name=etcd -e host_pattern=test_etcd_v2 -e initial_cluster_state=existing

8.	Manually replace failed node in cluster with new one.

		$ ssh user@192.168.56.101
		$ sudo etcdctlwrap member list
		5b464a2f75a38e65, started, etcd-c, https://k8s-3:2380, https://k8s-3:2379, false
		69e952a5a6a6e798, started, etcd-a, https://k8s-1:2380, https://k8s-1:2379, false
		aee4be324f12ea53, started, etcd-b, https://k8s-2:2380, https://k8s-2:2379, false
		$ sudo etcdctlwrap member remove aee4be324f12ea53
		$ sudo etcdctlwrap member add etcd-b --peer-urls=https://k8s-4:2380
		$ sudo etcdctlwrap member list
		14967b194abf439, started, etcd-b, https://k8s-4:2380, https://k8s-4:2379, false
		5b464a2f75a38e65, started, etcd-c, https://k8s-3:2380, https://k8s-3:2379, false
		69e952a5a6a6e798, started, etcd-a, https://k8s-1:2380, https://k8s-1:2379, false
		
9.	Check value is survived after all that.

		$ ssh user@192.168.56.104
		$ sudo etcdctlwrap get test-key
		test-key
		test value, hello from k8s-2






Upgrade to latest ansible
-----------------------------

Ansible 2.5.1 not supported by this playbook. 
There is a bug which prevents priviledge escalation when using include_role.
Also argv parameter not supported by command module.
Ansible 2.7 and higher seems to work.
On ubuntu upgrade ansible with the following commands

	sudo apt update
	sudo apt install software-properties-common
	sudo apt-add-repository --yes --update ppa:ansible/ansible
	sudo apt install ansible