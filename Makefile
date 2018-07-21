

target?=target
target_bin?=${target}/bin
target_cert?=${target}/cert
target_kubeconfig?=${target}/kubeconfig


controller_hosts?=127.0.0.1
worker_name?=default-worker
worker_host?=127.0.0.1

comma:=,
empty:=
space:=$(empty) $(empty)



.PHONY: all
all: cert



# download cfssl
ifneq (,$(shell which cfssl 2>/dev/null))
cfssl?=cfssl
else
cfssl?=${target_bin}/cfssl
endif
ifeq (cfssl,${cfssl})
cfssl:=$(shell which cfssl 2>/dev/null)
${cfssl}:	
	# cfssl must be in the path
else ifneq (,$(findstring cygwin,$(call lc,$(shell uname -a))))
${cfssl}:
	mkdir -p '$(dir $@)'
	curl -o "$@" https://pkg.cfssl.org/R1.2/cfssl_windows-amd64.exe
	chmod +x $@
else
${cfssl}:
	$(error unsupported platform $(shell uname) for cfssl) 
endif


# download cfssljson
ifneq (,$(shell which cfssljson 2>/dev/null))
cfssljson?=cfssljson
else
cfssljson?=${target_bin}/cfssljson
endif
ifeq (cfssljson,${cfssljson})
cfssljson:=$(shell which cfssljson 2>/dev/null)
${cfssljson}:
	# cfssljson must be in the path
else ifneq (,$(findstring Cygwin,$(call lc,$(shell uname -a))))
${cfssljson}:
	mkdir -p '$(dir $@)'
	curl -o "$@" https://pkg.cfssl.org/R1.2/cfssljson_windows-amd64.exe
	chmod +x $@
else
${cfssljson}:
	$(error unsupported platform $(shell uname) for cfssljson) 
endif


# download kubectl
ifneq (,$(shell which kubectl 2>/dev/null))
kubectl?=kubectl
else
kubectl?=${target_bin}/kubectl
endif
ifeq (kubectl,${kubectl})
kubectl:=$(shell which kubectl 2>/dev/null)
${kubectl}:
	# kubectl must be in the path
else ifneq (,$(findstring Cygwin,$(call lc,$(shell uname -a))))
${kubectl}:
	mkdir -p '$(dir $@)'
	curl -o "$@" https://storage.googleapis.com/kubernetes-release/archive/anago-v1.10.0-alpha.1/k8s.io/kubernetes/_output-v1.10.0-alpha.1/dockerized/bin/windows/amd64/kubectl.exe
	chmod +x $@
else
${kubectl}:
	$(error unsupported platform $(shell uname) for kubectl) 
endif








testtt:
	echo '$(call certfiles,${target_cert}/ca)'




















define certfiles
$(addprefix $(1),-key.pem .pem .csr)
endef



.PHONY: cert
cert: \
	$(call certfiles,${target_cert}/ca) \
	$(call certfiles,${target_cert}/admin) \
	$(call certfiles,${target_cert}/${worker_name}) \
	$(call certfiles,${target_cert}/kube-controller-manager) \
	$(call certfiles,${target_cert}/kube-proxy) \
	$(call certfiles,${target_cert}/kube-scheduler) \
	$(call certfiles,${target_cert}/kubernetes) \
	$(call certfiles,${target_cert}/service-account)



# Certificate Authority
$(call certfiles,${target_cert}/ca): src/ca-config.json src/ca-csr.json ${cfssl} ${cfssljson}
	mkdir -p '$(dir $@)'
	${cfssl} gencert \
	  -initca src/ca-csr.json \
	  -config=src/ca-config.json | ${cfssljson} -bare ${target_cert}/ca



# The Kubelet Client Certificates            admin
# The Controller Manager Client Certificate  kube-controller-manager
# The Kube Proxy Client Certificate          kube-proxy
# The Scheduler Client Certificate           kube-scheduler
# The Kubernetes API Server Certificate      kubernetes
# The Service Account Key Pair               service-account
$(call certfiles,${target_cert}/%): ${target_cert}/ca.pem ${target_cert}/ca-key.pem src/ca-config.json src/$*-csr.json ${cfssl} ${cfssljson}
	mkdir -p '$(dir $@)'
	${cfssl} gencert \
	  -ca=${target_cert}/ca.pem \
	  -ca-key=${target_cert}/ca-key.pem \
	  -config=src/ca-config.json \
	  -profile=kubernetes \
	  src/$*-csr.json | ${cfssljson} -bare ${target_cert}/$*



# The worker Client Certificates
${target_cert}/${worker_name}-csr.json: src/instance-csr.json
	mkdir -p '$(dir $@)'
	sed -e 's/{{name}}/${worker_name}/g; s/{{host}}/${worker_host}/g; ' $< > $@

$(call certfiles,${target_cert}/${worker_name}): ${target_cert}/${worker_name}-csr.json ${cfssl} ${cfssljson}
	mkdir -p '$(dir $@)'
	${cfssl} gencert \
	  -ca=${target_cert}/ca.pem \
	  -ca-key=${target_cert}/ca-key.pem \
	  -config=src/ca-config.json \
	  -hostname=${worker_host},127.0.0.1 \
	  -profile=kubernetes \
	  $< | ${cfssljson} -bare ${target_cert}/${worker_name}
















#
${target}/etcd.service: src/etcd.service.template



# build etcd for armv7
${target_bin}/etcd ${target_bin}/etcdctl:
	rm -rf '${target}/checkout/etcd'
	mkdir -p '${target}/checkout/etcd'
	git clone git@github.com:coreos/etcd.git '${target}/checkout/etcd'
	docker run --rm -it -v '${target}/checkout/etcd':/usr/src/myapp -w /usr/src/myapp -e GOOS=linux -e GOARCH=arm golang:1.9 bash ./build
	mkdir -p '$(dir $@)'
	cp '${target}/checkout/etcd/bin/etcd' '$@'
















${target_kubeconfig}/%.kubeconfig: ${target_cert}/ca.pem
	rm -rf '$@'
	mkdir -p $(dir $@)

	kubectl config set-cluster kubernetes-the-hard-way \
		--certificate-authority=${target_cert}/ca.pem \
		--embed-certs=true \
		--server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
		--kubeconfig='$@'

	kubectl config set-credentials system:node:${instance} \
		--client-certificate=${instance}.pem \
		--client-key=${instance}-key.pem \
		--embed-certs=true \
		--kubeconfig='$@'

	kubectl config set-context default \
		--cluster=kubernetes-the-hard-way \
		--user=system:node:${instance} \
		--kubeconfig='$@'

	kubectl config use-context default --kubeconfig=${instance}.kubeconfig



.PHONY: kubectl-shell
kubectl-shell:
