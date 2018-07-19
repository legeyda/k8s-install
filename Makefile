

target?=target
target_bin?=${target}/bin
target_cert?=${target}/cert

# controller_hosts should be set
worker_name?=default-worker
worker_host?=127.0.0.0.1

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
	echo '${cfssl} ${cfssljson}'


.PHONY: cert
cert: \
	${target_cert}/ca-key.pem                      ${target_cert}/ca.pem \
	${target_cert}/admin-key.pem                   ${target_cert}/admin.pem \
	${target_cert}/${worker_name}-key.pem          ${target_cert}/${worker_name}.pem \
	${target_cert}/kube-controller-manager-key.pem ${target_cert}/kube-controller-manager.pem \
	${target_cert}/kube-proxy-key.pem              ${target_cert}/kube-proxy.pem \
	${target_cert}/kube-scheduler-key.pem          ${target_cert}/kube-scheduler.pem



# Certificate Authority
${target_cert}/ca-key.pem ${target_cert}/ca.pem ${target_cert}/ca.csr: src/ca-config.json src/ca-csr.json ${cfssl} ${cfssljson}
	mkdir -p '$(dir $@)'
	${cfssl} gencert -initca src/ca-csr.json | ${cfssljson} -bare ${target_cert}/ca



# The Kubelet Client Certificates
${target_cert}/admin-key.pem ${target_cert}/admin.pem ${target_cert}/admin.csr: src/ca-config.json src/admin-csr.json ${target_cert}/ca.pem ${target_cert}/ca-key.pem ${cfssl} ${cfssljson}
	mkdir -p '$(dir $@)'
	${cfssl} gencert \
	  -ca=${target_cert}/ca.pem \
	  -ca-key=${target_cert}/ca-key.pem \
	  -config=src/ca-config.json \
	  -profile=kubernetes \
	  src/admin-csr.json | ${cfssljson} -bare ${target_cert}/admin



# The worker Client Certificates
${target_cert}/${worker_name}-csr.json: src/instance-csr.json
	mkdir -p '$(dir $@)'
	sed -e 's/{{name}}/${worker_name}/g; s/{{host}}/${worker_host}/g; ' $< > $@

${target_cert}/${worker_name}.pem ${target_cert}/${worker_name}-key.pem: ${target_cert}/${worker_name}-csr.json ${cfssl} ${cfssljson}
	mkdir -p '$(dir $@)'
	${cfssl} gencert \
	  -ca=${target_cert}/ca.pem \
	  -ca-key=${target_cert}/ca-key.pem \
	  -config=src/ca-config.json \
	  -hostname=${worker_host},127.0.0.1 \
	  -profile=kubernetes \
	  $< | ${cfssljson} -bare ${target_cert}/${worker_name}



# The Controller Manager Client Certificate
${target_cert}/kube-controller-manager-key.pem ${target_cert}/kube-controller-manager.pem: ${target_cert}/ca.pem ${target_cert}/ca-key.pem src/ca-config.json src/kube-controller-manager-csr.json ${cfssl} ${cfssljson}
	mkdir -p '$(dir $@)'
	${cfssl} gencert \
	  -ca=${target_cert}/ca.pem \
	  -ca-key=${target_cert}/ca-key.pem \
	  -config=src/ca-config.json \
	  -profile=kubernetes \
	  src/kube-controller-manager-csr.json | ${cfssljson} -bare ${target_cert}/kube-controller-manager



# The Kube Proxy Client Certificate
${target_cert}/kube-proxy-key.pem ${target_cert}/kube-proxy.pem: ${target_cert}/ca.pem ${target_cert}/ca-key.pem src/ca-config.json ${cfssl} ${cfssljson}
	mkdir -p '$(dir $@)'
	${cfssl} gencert \
	  -ca=${target_cert}/ca.pem \
	  -ca-key=${target_cert}/ca-key.pem \
	  -config=src/ca-config.json \
	  -profile=kubernetes \
	  src/kube-proxy-csr.json | ${cfssljson} -bare ${target_cert}/kube-proxy



# The Scheduler Client Certificate
${target_cert}/kube-scheduler-key.pem ${target_cert}/kube-scheduler.pem: src/ca-config.json src/kube-scheduler-csr.json ${target_cert}/ca.pem ${target_cert}/ca-key.pem ${cfssl} ${cfssljson}
	mkdir -p '$(dir $@)'
	${cfssl} gencert \
	  -ca=${target_cert}/ca.pem \
	  -ca-key=${target_cert}/ca-key.pem \
	  -config=src/ca-config.json \
	  -profile=kubernetes \
	  src/kube-scheduler-csr.json | ${cfssljson} -bare ${target_cert}/kube-scheduler



# The Kubernetes API Server Certificate
${target_cert}/kubernetes-key.pem ${target_cert}/kubernetes.pem: src/ca-config.json src/kubernetes-csr.json ${target_cert}/ca.pem ${target_cert}/ca-key.pem ${cfssl} ${cfssljson}
	@test -n '${controller_hosts}' # variable controller_hosts must have comma-separated addresses of controller hosts
	mkdir -p '$(dir $@)'
	${cfssl} gencert \
	  -ca=${target_cert}/ca.pem \
	  -ca-key=${target_cert}/ca-key.pem \
	  -config=src/ca-config.json \
	  -hostname=$(subst ${space},${comma},${controller_hosts}),https://127.0.0.1 \
	  -profile=kubernetes \
	  src/kubernetes-csr.json | ${cfssljson} -bare ${target_cert}/kubernetes


# The Service Account Key Pair
${target_cert}/service-account-key.pem ${target_cert}/service-account.pem: src/ca-config.json src/service-account-csr.json ${target_cert}/ca.pem ${target_cert}/ca-key.pem ${cfssl} ${cfssljson}
	mkdir -p '$(dir $@)'
	${cfssl} gencert \
	  -ca=${target_cert}/ca.pem \
	  -ca-key=${target_cert}/ca-key.pem \
	  -config=src/ca-config.json \
	  -profile=kubernetes \
	  src/service-account-csr.json | ${cfssljson} -bare ${target_cert}/service-account



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