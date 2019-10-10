



main() {

	local dir=target/test-cfssl

	rm -rf "${dir}"
	mkdir -p "${dir}"
	mkdir "${dir}/ca" "$dir/cert"


	target/bin/cfssl gencert -initca src/cert/ca/csr.json -config=src/cert/ca/config.json | \
			target/bin/cfssljson -bare "${dir}/ca/ca"

	target/bin/cfssl genkey  -initca src/cert/ca/csr.json -config=src/cert/ca/config.json | \
			target/bin/cfssljson -bare "${dir}/cert/cert"


	target/bin/cfssl sign -ca $dir/ca/ca.pem -ca-key $dir/ca/ca-key.pem \
			-config=src/cert/ca/config.json -profile default $dir/cert/cert.csr | \
			target/bin/cfssljson -bare $dir/cert/cert


}


main "$@"


