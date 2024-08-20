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

## Backup ClusterAPI Files

Before proceeding with `Dogfooding ClusterAPI`, execute this command :

```sh
mkdir ./management-cluster/clusterapi-backup
clusterctl move -n capi-cluster-kubeaid-demo \
	--to-directory ./management-cluster/clusterapi-backup
```

and take a backup of your ClusterAPI related files.

Let's say you dogfood ClusterAPI. Then somehow seriously mess up the CNI plugin due to which pod-to-pod communication gets disrupted. These backup files will come to rescue then!

## Dogfooding ClusterAPI

We'll make the provisioned cluster manage itself, so there'll be no need for the management cluster.

1. Create a Sealed Secret (in your kubeaid-config) out of `./management-cluster/capi-cluster-token.secret.yaml` using this command :

   ```sh
   KUBECONFIG=./main-cluster/kubeconfig.yaml \
   	kubeseal -f ./management-cluster/capi-cluster-token.secret.yaml \
   	-w ../../kubeaid-config/k8s/test.cluster.com/sealed-secrets/capi-cluster-kubeaid-demo/capi-cluster-token.sealed-secret.yaml \
   	--controller-name sealed-secrets --controller-namespace system
   ```

   Commit and push the change.

2. Create the root ArgoCD app in the main cluster :

   ```sh
   helm template ../../kubeaid-config/k8s/test.cluster.com/argocd-apps > ./main-cluster/root.app.argocd.yaml
   KUBECONFIG=./main-cluster/kubeconfig.yaml kubectl apply -f ./main-cluster/root.app.argocd.yaml
   ```

3. Create the `capi-cluster-kubeaid-demo` namespace in the main cluster :

   ```sh
   KUBECONFIG=./main-cluster/kubeconfig.yaml kubectl create namespace capi-cluster-kubeaid-demo
   ```

4. Then sync the `root`, `Sealed Secrets` and `Cluster API` ArgoCD apps. Sync the `InfrastructureProvider` resource of the `CAPI Cluster` ArgoCD app.

5. Then move the Cluster API resources from the management to the main cluster :

   ```sh
   clusterctl move --to-kubeconfig=./main-cluster/kubeconfig.yaml -n capi-cluster-kubeaid-demo
   ```

And done....!

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

- [x] Dogfooding - let the main cluster manage itself, so we don't need the management cluster once the main cluster is provisioned.
- [ ] Build and publish our own AMIs. Currently, there are no community maintained AMIs for ARM machines and Kubernetes versions above v1.28.3.
- [ ] Check whether we can directly upgrade the Kubernetes cluster from v1.27 to 1.30.
- [ ] Deploy a sample stateful and stateless application.
- [ ] Test node autoscaling by load testing.

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

- [clusterctl move command](https://cluster-api.sigs.k8s.io/clusterctl/commands/move)

- [Cilium netkit: The Final Frontier in Container Networking Performance](https://isovalent.com/blog/post/cilium-netkit-a-new-container-networking-paradigm-for-the-ai-era/)
