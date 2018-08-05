

target?=target
target_download?=${target}/download
target_lib=${target}/lib
target_cert?=${target}/cert
target_cert_system?=${target_cert}/system
target_cert_instance?=${target_cert}/instance
target_kubeconfig?=${target}/kubeconfig

cluster_hosts?=127.0.0.1

etcd_node_hosts?=127.0.0.1
k8s_controller_hosts?=127.0.0.1
k8s_worker_hosts?=127.0.0.1



k8s_worker_name?=
k8s_worker_host?=




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

# build etcd for armv7
${target_lib}/linux/%/etcd ${target_lib}/linux/%/etcdctl:
	rm -rf '${target}/checkout/etcd'
	mkdir -p '${target}/checkout/etcd'
	git clone git@github.com:coreos/etcd.git '${target}/checkout/etcd'
	docker run --rm -it -v '${target}/checkout/etcd':/usr/src/myapp -w /usr/src/myapp -e GOOS=linux -e GOARCH=$* golang:1.9 bash ./build
	mkdir -p '$(dir $@)'
	cp '${target}/checkout/etcd/bin/etcd' '$@'

# 
${target_lib}/linux/arm/kube%:
	${download} --output '$@' ${k8s_binary_url}/linux/arm/kube$*
	chmod +x '$@'














# ======== CERTIFICATES ========


define certfiles
$(addprefix $(1),-key.pem .pem .csr)
endef

.PHONY: cert
cert: \
	$(call certfiles,${target_cert_system}/ca) \
	$(call certfiles,${target_cert_system}/admin) \
	$(call certfiles,${target_cert_system}/kube-controller-manager) \
	$(call certfiles,${target_cert_system}/kube-proxy) \
	$(call certfiles,${target_cert_system}/kube-scheduler) \
	$(call certfiles,${target_cert_system}/kubernetes) \
	$(call certfiles,${target_cert_system}/service-account)
	$(call certfiles,${target_cert_instance}/${k8s_worker_name}) \


.PHONY: clean-cert
clean-cert:
	rm -rf '${target_cert}'


# Certificate Authority root cert
$(call certfiles,${target_cert_system}/ca): src/cert/ca-config.json src/cert/ca-csr.json ${cfssl} ${cfssljson}
	mkdir -p '$(dir $@)'
	${cfssl} gencert \
	  -initca src/cert/ca-csr.json \
	  -config=src/cert/ca-config.json | ${cfssljson} -bare ${target_cert_system}/ca


# system certificates (fixed lixt)
# The Kubelet Client Certificates            admin
# The Controller Manager Client Certificate  kube-controller-manager
# The Kube Proxy Client Certificate          kube-proxy
# The Scheduler Client Certificate           kube-scheduler
# The Kubernetes API Server Certificate      kubernetes
# The Service Account Key Pair               service-account
$(call certfiles,${target_cert_system}/${percent}): src/cert/%-csr.json ${target_cert_system}/ca.pem ${target_cert_system}/ca-key.pem src/cert/ca-config.json ${target}/cluster_hosts ${cfssl} ${cfssljson}
	mkdir -p '$(dir $@)'
	${cfssl} gencert \
	  -ca=${target_cert_system}/ca.pem \
	  -ca-key=${target_cert_system}/ca-key.pem \
	  -config=src/cert/ca-config.json \
	  -profile=kubernetes \
	  -hostname=$(file < ${target}/cluster_hosts),127.0.0.1 \
	  $< | ${cfssljson} -bare ${target_cert_system}/$*





# node certificates (environment-dependent list)
${target_cert_node}/%-csr.json: src/cert/node-csr.json.template ${target_cert_node}/%-cn.txt
	mkdir -p '$(dir $@)'
	sed -e 's/{{name}}/$(file < $(word 2,$^))/g' $< > $@

$(call certfiles,${target_cert_node}/${percent}): ${target_cert_node}/%-csr.json ${target}/cluster_hosts ${cfssl} ${cfssljson}
	mkdir -p '$(dir $@)'
	${cfssl} gencert \
	  -ca=${target_cert_system}/ca.pem \
	  -ca-key=${target_cert_system}/ca-key.pem \
	  -config=src/cert/ca-config.json \
	  -hostname=$(file < ${target}/cluster_hosts),127.0.0.1 \
	  -profile=kubernetes \
	  $< | ${cfssljson} -bare ${target_cert_node}/$*



















${target}/cn/%:
	mkdir -p '$(dir $@)'
	test -f src/cn/$* && cp src/cn/$* ${target}/cn/$* || $(file > ${target}/cn/$*,$*)


# remote kubeconfig
${target_kubeconfig}/remote/%.kubeconfig: ${target_cert_system}/ca.pem ${target_cert_system}%.pem ${target_cert_system}/%-key.pem src/var/cn/% ${target}/cn/%
	rm -rf '$@'
	mkdir -p '$(dir $@)'

	kubectl config set-cluster k8s-cluster \
		--certificate-authority=${target_cert_system}/ca.pem \
		--embed-certs=true \
		--server=https://127.0.0.1:6443 \
		--kubeconfig='$@'

	kubectl config set-credentials system:node:${instance} \
		--client-certificate=${target_cert_system}/$*.pem \
		--client-key=${target_cert_system}/$*-key.pem \
		--embed-certs=true \
		--kubeconfig='$@'

	kubectl config set-context default \
		--cluster=k8s-cluster \
		--user=$(file < src/cn/$*) \
		--kubeconfig='$@'

	kubectl config use-context default --kubeconfig=$@




target/encryption-key:
	head -c 32 /dev/urandom | base64 | tr -d '\n' > '$@'