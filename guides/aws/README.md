# Demonstrating KubeAid

> KubeAid is a Kubernetes management suite, offering a way to setup and operate K8s clusters, following gitops and automation principles.

## Provisioning a cluster

Fork the [KubeAid](https://github.com/Obmondo/kubeaid) and [KubeAid config](https://github.com/Obmondo/kubeaid-config) repos. Here are my forks - https://github.com/Archisman-Mridha/kubeaid and https://github.com/Archisman-Mridha/kubeaid-config.

Next, export your AWS credentials as environment variables :
```sh
export CUSTOMERID=
export AWS_REGION=
export AWS_ACCESS_KEY_ID=
export AWS_SECRET_ACCESS_KEY=
```

Next, create an AWS Keypair named `kubeaid-demo` in the `us-east-2` region. Here is the link to the documentation - https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/create-key-pairs.html.

Then execute the commands specified in [commands.sh](./commands.sh) file. Once the main cluster is provisioned, go ahead and use K9s to explore it :
```sh
KUBECONFIG=./main-cluster/kubeconfig.yaml k9s
```

> One thing you may notice is the `AWS Cloud Controller Manager (aws-ccm)` pod is running in the `kube-system` namespace instead of the `aws` namepsace. This is mandatory!

## Solving the DNS issue in the provisioned cluster

> Following https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/.
> I also removed the Cilium kube-proxyless mode to be sure that it wasn't the reason behind.

I launched a utility pod and shelled into it :

```sh
kubectl create deployment dns-issue-debugger --image=wbitt/network-multitool:latest
```

> I was able to communicate with `google.com` by executing `ping 8.8.8.8` but not using `ping google.com`.

Got the local DNS configuration using `cat /etc/resolv.conf` :

```conf
search default.svc.cluster.local svc.cluster.local cluster.local us-east-2.compute.internal
nameserver 10.96.0.10
options ndots:5
```

`nslookup kubernetes.default` was timing out and when I pinged `10.96.0.10` (ClusterIP of the KubeDNS / CoreDNS Service) manually, I didn't receive any response.

Let's try to deploy the utility pod in the same node as CoreDNS and check whether this problem goes away or not. The output for `nslookup kubernetes.default` I got this time is :

```log
Server:		10.96.0.10
Address:	10.96.0.10#53

Name:	kubernetes.default.svc.cluster.local
Address: 10.96.0.1
```

Everything works fine (even `ping google.com`)!

> So the issue here is : cross node communication!
> Workloads run on worker nodes. Now, to resolve a DNS hostname, a pod in the worker node tries to communicate with CoreDNS (which is running in the control node). And this communication fails.

Let's get outside Kubernetes and try to communicate with a control-plane node from a worker node.

```sh
# SSH into the Bastian.
scp -i kubeaid-demo.pem ./kubeaid-demo.pem ubuntu@3.146.107.141:/home/ubuntu/kubeaid-demo.pem
ssh -i ./kubeaid-demo.pem ubuntu@3.146.107.141

# SSH into a worker node.
scp -i kubeaid-demo.pem ./kubeaid-demo.pem ubuntu@10.14.1.139:/home/ubuntu/kubeaid-demo.pem
ssh -i kubeaid-demo.pem ubuntu@10.14.1.139

# Try to SSH into the control-plane node.
ssh -i kubeaid-demo.pem ubuntu@10.14.0.48 # The SSH fails. However I can see that there is a
																					# Security Group attached, which allows inbound SSH
																					# connections to port 22.
```

> https://serverfault.com/questions/483938/multiple-ec2-security-groups-permissive-or-restrictive

## Dogfooding ClusterAPI

```sh
helm template ../../kubeaid-config/k8s/test.cluster.com/argocd-apps > ./main-cluster/root.app.argocd.yaml
KUBECONFIG=./main-cluster/kubeconfig.yaml kubectl apply -f ./main-cluster/root.app.argocd.yaml
```

## Upgrading the cluster

> Currently, there are no community maintained AMIs for Kubernetes versions higher than v1.28.3. So, we'll try to downgrade the cluster.

Let's say, you want to downgrade the Kubernetes version of the main cluster from v1.28.3 to v1.28.2.

- Change the Kubernetes version to v1.28.11 in `k8s/test.cluster.com/argocd-apps/values-capi-cluster.yaml` in your `kubeaid-config` fork. Commit and push that change.

- Sync the CAPI Cluster ArgoCD app in ArgoCD dashboard.

- Observe the logs of the `capa-controller-manager` pod in the `capi-cluster-kubeaid-demo` namespace. You'll see the existing EC2 instances getting terminated and new EC2 instances coming up.

You can verify the downgrade by executing :
```sh
KUBECONFIG=./main-cluster/kubeconfig.yaml kubectl version
```
and checking the `Kubernetes server version`.

## TODOS

- [ ] Deploy a sample stateful and stateless application.
- [ ] Test node autoscaling by load testing.
- [ ] Build and publish our own AMIs. Currently, there are no community maintained AMIs for Kubernetes versions above v1.28.3 / ARM machines.
- [ ] Dogfooding - let the main cluster manage itself, so we don't need the management cluster once the main cluster is provisioned.
- [ ] Fix : hubble-relay pod is failing with error - `Failed to create peer client for peers synchronization`.
- [ ] Deploy a bw7 cluster using Cluster Api (next week).
- [ ] Check whether we can directly upgrade the Kubernetes cluster from v1.28.3 to v1.29.1.

## REFERENCES

- [Cluster API Provider AWS Official repo](https://github.com/kubernetes-sigs/cluster-api-provider-aws)

- [Cluster API and CAPI Cluster Helm charts](https://gitea.obmondo.com/EnableIT/KubeAid/pulls/247/files#diff-46d69d9f3f79a73097337b7b5ee2da815b6d6631)

- [Values files for Cluster API and CAPI Cluster Helm charts](https://gitea.obmondo.com/EnableIT/kubeaid-config-enableit/pulls/547/files)

- [Metadata propagation through ClusterAPI related CRs](https://cluster-api.sigs.k8s.io/developer/architecture/controllers/metadata-propagation)

- [SKipping kube-proxy installation during kubeadm bootstrap phase](https://github.com/kubernetes-sigs/cluster-api/issues/10237#issuecomment-1985386521)

- [HelmChartProxy quick start guide](https://github.com/kubernetes-sigs/cluster-api-addon-provider-helm/blob/main/docs/quick-start.md#4-example-install-nginx-ingress-to-the-workload-cluster)

- [Criterias for a Cluster Infrastructure Provider](https://release-0-3.cluster-api.sigs.k8s.io/developer/providers/cluster-infrastructure)

- [Can we ignore a template to be rendered but create the manifest as it is](https://github.com/helm/helm/issues/9667)

- [Debugging DNS Resolution](https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/)
