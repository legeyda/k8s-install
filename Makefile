

target?=target
target_download?=${target}/download
target_lib=${target}/lib
target_cert?=${target}/cert
target_kubeconfig?=${target}/kubeconfig

cluster_hosts?=127.0.0.1
worker_name?=default-worker
worker_host?=127.0.0.1

comma:=,
empty:=
space:=$(empty) $(empty)
percent:=%


curl?=curl
download:=${curl} --location --create-dirs
k8s_binary_url?=https://storage.googleapis.com/kubernetes-release/archive/anago-v1.10.0-alpha.1/k8s.io/kubernetes/_output-v1.10.0-alpha.1/gcs-stage/v1.10.0-alpha.1/bin


# os
ifneq (,$(findstring cygwin,$(shell uname -a | tr A-Z a-z)))
os:=windows
else
os:=unknown
endif

# arch
ifneq (,$(findstring x86_64,$(shell uname -a | tr A-Z a-z)))
arch:=amd64
else
arch:=unknown
endif




testtt:
	bash -c 'bash --init-file < (echo "echo hello")'








.PHONY: all
all: cert











# ======== LOCAL MACHINE TOOLS ========


cfssl?=${target_lib}/${os}/${arch}/cfssl
cfssljson?=${target_lib}/${os}/${arch}/cfssljson
kubectl?=${target_lib}/${os}/${arch}/kubectl
etcdctl?=${target_lib}/${os}/${arch}/etcdctl


${target_lib}/windows/amd64/cfssl:
	${download} '$@' https://pkg.cfssl.org/R1.2/cfssl_windows-amd64.exe
	chmod +x '$@'

${target_lib}/windows/amd64/cfssljson:
	${download} '$@' https://pkg.cfssl.org/R1.2/cfssljson_windows-amd64.exe
	chmod +x '$@'

${target_lib}/windows/amd64/kubectl:
	${download} '$@' ${k8s_binary_url}/windows/amd64/kubectl.exe
	chmod +x '$@'

${target_lib}/windows/amd64/etcdctl:
	rm -rf '${target_download}'/etcd-v3.3.8-windows-amd64*
	${download} --output '${target_download}/etcd-v3.3.8-windows-amd64.zip' https://github.com/coreos/etcd/releases/download/v3.3.8/etcd-v3.3.8-windows-amd64.zip
	cd ${target_download}; unzip etcd-v3.3.8-windows-amd64
	cp ${target_download}/etcd-v3.3.8-windows-amd64/etcdctl.exe '$@'
	chmod +x '$@'













# ======== CERTIFICATES ========


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

.PHONY: clean-cert
clean-cert:
	rm -rf '${target_cert}'


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
$(call certfiles,${target_cert}/${percent}): ${target_cert}/ca.pem ${target_cert}/ca-key.pem src/ca-config.json src/%-csr.json ${cfssl} ${cfssljson}
	mkdir -p '$(dir $@)'
	${cfssl} gencert \
	  -ca=${target_cert}/ca.pem \
	  -ca-key=${target_cert}/ca-key.pem \
	  -config=src/ca-config.json \
	  -profile=kubernetes \
	  -hostname=${cluster_hosts},127.0.0.1 \
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













# ======== ARM BINARIES ========

# build etcd for armv7
${target_lib}/linux/arm/etcd ${target_lib}/linux/arm/etcdctl:
	rm -rf '${target}/checkout/etcd'
	mkdir -p '${target}/checkout/etcd'
	git clone git@github.com:coreos/etcd.git '${target}/checkout/etcd'
	docker run --rm -it -v '${target}/checkout/etcd':/usr/src/myapp -w /usr/src/myapp -e GOOS=linux -e GOARCH=arm golang:1.9 bash ./build
	mkdir -p '$(dir $@)'
	cp '${target}/checkout/etcd/bin/etcd' '$@'

# 
${target_lib}/linux/arm/kube%:
	${download} --output '$@' ${k8s_binary_url}/linux/arm/kube$*
	chmod +x '$@'































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

