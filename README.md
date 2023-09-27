# canary-deployment-with-istio

## Cluster Installation
- Install GKE cluster
```sh
export TF_VAR_project_id=<PROJECT_ID>
export TF_VAR_my_source_address="$(curl -s ipinfo.io/ip)/32"

cd infrastructure/terraform
terraform apply
```

- Configure kubeconfig file
```sh
gcloud container clusters get-credentials <CLUSTER_NAME> --zone <ZONE> --project <PROJECT_ID>
```

- Install Istio control plane
Install Istio with istioctl: we are going to use the `default` profile (with components: Istio core, Istiod, and Ingress gateways)
```sh
istioctl install --verify
```

- Install cert-manager
Install cert-manager using static install and GKE Workload Identity (IAM prerequisites have been setup via Terraform)
```sh
KSA_NAME_CM="cert-manager"
NAMESPACE_CM="cert-manager"
GSA_NAME_CM="gsa-cert-manager"
GCP_PROJECT_ID=<PROJECT_ID>
kubectl create namespace $NAMESPACE_CM
kubectl -n $NAMESPACE_CM create serviceaccount $KSA_NAME_CM
kubectl -n $NAMESPACE_CM annotate serviceaccount $KSA_NAME_CM "iam.gke.io/gcp-service-account=${GSA_NAME_CM}@${GCP_PROJECT_ID}.iam.gserviceaccount.com"

kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.1/cert-manager.yaml
```

- Install external-DNS
```sh
KSA_NAME_ED="external-dns"
NAMESPACE_ED="external-dns"
GSA_NAME_ED="gsa-external-dns"
GCP_PROJECT_ID=<PROJECT_ID>
kubectl create namespace $NAMESPACE_ED
kubectl -n $NAMESPACE_ED create serviceaccount $KSA_NAME_ED
kubectl -n $NAMESPACE_ED annotate serviceaccount $KSA_NAME_ED "iam.gke.io/gcp-service-account=${GSA_NAME_ED}@${GCP_PROJECT_ID}.iam.gserviceaccount.com"

kubectl apply -f infrastructure/kubernetes/external-dns.yaml
```

## Application sample
```sh



kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.19/samples/bookinfo/platform/kube/bookinfo.yaml
 kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.19/samples/bookinfo/networking/bookinfo-gateway.yaml


export INGRESS_NAME=istio-ingressgateway
export INGRESS_NS=istio-system
export INGRESS_HOST=$(kubectl -n "$INGRESS_NS" get service "$INGRESS_NAME" -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
export INGRESS_PORT=$(kubectl -n "$INGRESS_NS" get service "$INGRESS_NAME" -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')
export SECURE_INGRESS_PORT=$(kubectl -n "$INGRESS_NS" get service "$INGRESS_NAME" -o jsonpath='{.spec.ports[?(@.name=="https")].port}')
export TCP_INGRESS_PORT=$(kubectl -n "$INGRESS_NS" get service "$INGRESS_NAME" -o jsonpath='{.spec.ports[?(@.name=="tcp")].port}')
export GATEWAY_URL=$INGRESS_HOST:$INGRESS_PORT

curl -s "http://${GATEWAY_URL}/productpage" | grep -o "<title>.*</title>"

```


https://istio.io/latest/docs/tasks/traffic-management/traffic-shifting/
https://istio.io/latest/docs/tasks/observability/gateways/
