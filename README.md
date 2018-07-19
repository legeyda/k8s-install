







{% for host in hostvars -%}
  {% if defined hostvars[host].name %}
    {{hostvars[host].name}}=https://{{host}}{% if not loop.last %},{% endif %}
  {% endif %}
{%- endfor %}

ETCDCTL_API=3 etcdctl member list --endpoints=https://127.0.0.1:2379 --cacert=/etc/etcd/ca.pem --cert=/etc/etcd/kubernetes.pem --key=/etc/etcd/kubernetes-key.pem







ExecStart=/usr/local/bin/etcd \
  --name {{name}} \
  --cert-file /etc/etcd/kubernetes.pem \
  --key-file /etc/etcd/kubernetes-key.pem \
  --peer-cert-file /etc/etcd/kubernetes.pem \
  --peer-key-file /etc/etcd/kubernetes-key.pem \
  --trusted-ca-file /etc/etcd/ca.pem \
  --peer-trusted-ca-file /etc/etcd/ca.pem \
  --peer-client-cert-auth \
  --client-cert-auth \
  --initial-advertise-peer-urls https://{{inventory_hostname}}:2380 \
  --listen-peer-urls https://{{inventory_hostname}}:2380 \
  --listen-client-urls https://{{inventory_hostname}}:2379,https://127.0.0.1:2379 \
  --advertise-client-urls https://{{inventory_hostname}}:2379 \
  --initial-cluster-token etcd-cluster-0 \
  --initial-cluster {{initial_cluster}} \
  --initial-cluster-state new \
  --data-dir /var/lib/etcd