# canary-deployment-with-istio

This example shows a simplyfied version of a real **canary deployment** in a production cluster.

In this repository you can find:
- A battle-tested `Terraform` code for creating a private Google Kubernetes Engine (GKE)
- Basic configurations for installing `cert-manager` and `external-dns` in a GKE with Workload Identity enabled
- A simple service exposed by using `Istio` ingress-gateway
- Canary deployment with `Istio`


## Install GKE cluster and configure tools for the battlefield
- Install GKE cluster
Review values in [main.tf](infrastructure/terraform/main.tf), then apply the Terraform code
```sh
export PROJECT_ID=<PROJECT_ID>
export TF_VAR_project_id="$PROJECT_ID"
export TF_VAR_my_source_address="$(curl -s ipinfo.io/ip)/32"

cd infrastructure/terraform
terraform apply
```

- Configure kubeconfig file
```sh
gcloud container clusters get-credentials <CLUSTER_NAME> --zone <ZONE> --project $PROJECT_ID
```

- Install Istio control plane
Install `Istio` with `istioctl` command line: I'm going to use the `default` profile which contains needed components for this example (Istio core, Istiod, and Ingress gateways)
```sh
istioctl install -y --verify
```

- Adapt yaml files to your environment
```sh
find . -type f -name "*.yaml" -exec sed -i '' s/DNS_DOMAIN/example-domain.com/g {} +
find . -type f -name "*.yaml" -exec sed -i '' s/GCP_PROJECT/gcp-project-id/g {} +
```

- Install cert-manager
Install `cert-manager` using a static installation method.
I'm setting an ACME issuer with DNS01 challange and Google Cloud DNS, so `cert-manager` will impersonate a Google Service Account to answer to challanges (see official [documentation](https://cert-manager.io/docs/configuration/acme/dns01/google/#gke-workload-identity) and [IAM prerequisites in Terraform code](infrastructure/terraform/iam.tf)). Kubernetes ServiceAccount is linked to the GSA by using the GKE Workload Identity which is strongly recommended as a security best practise
```sh
KSA_NAME_CM="cert-manager"
NAMESPACE_CM="cert-manager"
GSA_NAME_CM="gsa-cert-manager"
kubectl create namespace $NAMESPACE_CM
kubectl -n $NAMESPACE_CM create serviceaccount $KSA_NAME_CM
kubectl -n $NAMESPACE_CM annotate serviceaccount $KSA_NAME_CM "iam.gke.io/gcp-service-account=${GSA_NAME_CM}@${PROJECT_ID}.iam.gserviceaccount.com"

kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.1/cert-manager.yaml
```

- Install external-DNS
`ExternalDNS` is keeping in sync hostnames defined in Kubernetes `Ingresses` or `Services` with a DNS provider (e.g. Google Cloud DNS in this example), so it will impersonate a Google Service Account to write records in the managed zone (see official [documentation](https://kubernetes-sigs.github.io/external-dns/v0.13.6/tutorials/gke/#workload-identity) and [IAM prerequisites in Terraform code](infrastructure/terraform/iam.tf)).
`ExternalDNS` supports Istio ingress-gateway as well, please read the [related documentation](https://kubernetes-sigs.github.io/external-dns/v0.13.6/tutorials/istio/#manifest-for-clusters-without-rbac-enabled)
```sh
KSA_NAME_ED="external-dns"
NAMESPACE_ED="external-dns"
GSA_NAME_ED="gsa-external-dns"
kubectl create namespace $NAMESPACE_ED
kubectl -n $NAMESPACE_ED create serviceaccount $KSA_NAME_ED
kubectl -n $NAMESPACE_ED annotate serviceaccount $KSA_NAME_ED "iam.gke.io/gcp-service-account=${GSA_NAME_ED}@${PROJECT_ID}.iam.gserviceaccount.com"

kubectl apply -f infrastructure/kubernetes/external-dns/
```

- Create a `ClusterIssuer` and request a signed certificate to Let's Encrypt
At the moment `Istio` ingress-gateway is not fully integrated with `cert-manager`, so certificates needs to be issued as `Certificates` object in Kubernetes
```sh
kubectl apply -f infrastructure/kubernetes/cert-manager/
```

## Deploy application
Application consists of one frontend which is calling a backend:
- **Frontend** is exposed outside the cluster with an `Istio Ingress Gateway` which is creating a Google Load Balancer (Network Passthrough target-pool) and managing the TLS termination by using the certificate issued with `cert-manager`
Moreover `A` record will be automatically added in Cloud DNS by `external-dns` without any manual action.
- There are three different versions of the same **backend**

All application's components are running in a `Namespace` with label `istio-injection=enabled` which is enabling the automatic injection of the proxy sidecar, hence `Pods` will automatically join the service mesh.

- Create namespace
```sh
kubectl create namespace app
kubectl label namespace app istio-injection=enabled
```

- Deploy backend versions and destination rules for canary deployment
```sh
kubectl apply -f application/backend/
configmap/index-html-configmap-alpha created
configmap/index-html-configmap-beta created
configmap/index-html-configmap-ga created
deployment.apps/backend-deploy-alpha created
deployment.apps/backend-deploy-beta created
deployment.apps/backend-deploy-ga created
service/backend-svc created
```

- Deploy frontend and Istio Gateway
```sh
$ kubectl apply -f application/frontend/
configmap/frontend-nginx-conf-file created
deployment.apps/frontend-deploy created
certificate.cert-manager.io/webserver created
gateway.networking.istio.io/tls-gateway created
virtualservice.networking.istio.io/gateway-vs created
service/frontend-svc created
```

In a few minutes you will have the issued certificate annd your logs will look like the following
```sh
$ kubectl -n istio-system get events --sort-by='.lastTimestamp'
...
3m24s       Normal    Issuing                   certificate/webserver                          Issuing certificate as Secret does not exist
3m23s       Normal    WaitingForApproval        certificaterequest/webserver-1                 Not signing CertificateRequest until it is Approved
3m23s       Normal    OrderPending              certificaterequest/webserver-1                 Waiting on certificate issuance from order istio-system/webserver-1-2855599049: ""
3m23s       Normal    OrderCreated              certificaterequest/webserver-1                 Created Order resource istio-system/webserver-1-2855599049
3m23s       Normal    cert-manager.io           certificaterequest/webserver-1                 Certificate request has been approved by cert-manager.io
3m23s       Normal    WaitingForApproval        certificaterequest/webserver-1                 Not signing CertificateRequest until it is Approved
3m23s       Normal    WaitingForApproval        certificaterequest/webserver-1                 Not signing CertificateRequest until it is Approved
3m23s       Normal    WaitingForApproval        certificaterequest/webserver-1                 Not signing CertificateRequest until it is Approved
3m23s       Normal    WaitingForApproval        certificaterequest/webserver-1                 Not signing CertificateRequest until it is Approved
3m23s       Normal    Generated                 certificate/webserver                          Stored new private key in temporary Secret resource "webserver-7zwgw"
3m23s       Normal    Requested                 certificate/webserver                          Created new CertificateRequest resource "webserver-1"
3m18s       Normal    CertificateIssued         certificaterequest/webserver-1                 Certificate fetched from issuer successfully
3m18s       Normal    Complete                  order/webserver-1-2855599049                   Order completed successfully
3m18s       Normal    Issuing                   certificate/webserver                          The certificate has been successfully issued


$ kubectl -n istio-system get certificate
NAME        READY   SECRET                         AGE
webserver   True    frontend-ingress-gateway-tls   6m4s


$ kubectl -n istio-system get secrets frontend-ingress-gateway-tls -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -subject -dates
subject=CN = frontend.example-domain.com
notBefore=Oct  2 14:33:05 2023 GMT
notAfter=Dec 31 14:33:04 2023 GMT


$ kubectl -n external-dns logs $( kubectl -n external-dns get po -lapp.kubernetes.io/name=external-dns -o jsonpath='{.items[0].metadata.name}') | tail -10
{"level":"info","msg":"All records are already up to date","time":"2023-10-02T15:34:18Z"}
{"level":"info","msg":"All records are already up to date","time":"2023-10-02T15:35:19Z"}
{"level":"info","msg":"All records are already up to date","time":"2023-10-02T15:36:20Z"}
{"level":"info","msg":"Change zone: public-mz batch #0","time":"2023-10-02T15:37:21Z"}
{"level":"info","msg":"Add records: a-frontend.example-domain.com. TXT [\"heritage=external-dns,external-dns/owner=external-dns,external-dns/resource=gateway/istio-system/tls-gateway\"] 300","time":"2023-10-02T15:37:21Z"}
{"level":"info","msg":"Add records: frontend.example-domain.com. A [X.Y.Z.W] 300","time":"2023-10-02T15:37:21Z"}
{"level":"info","msg":"Add records: webserver.example-domain.com. TXT [\"heritage=external-dns,external-dns/owner=external-dns,external-dns/resource=gateway/istio-system/tls-gateway\"] 300","time":"2023-10-02T15:37:21Z"}
{"level":"info","msg":"All records are already up to date","time":"2023-10-02T15:38:22Z"}
{"level":"info","msg":"All records are already up to date","time":"2023-10-02T15:39:23Z"}
{"level":"info","msg":"All records are already up to date","time":"2023-10-02T15:40:23Z"}


$ istioctl proxy-config listener $(kubectl get pod --selector app=istio-ingressgateway --output jsonpath='{.items[0].metadata.name}' -n istio-system) -n istio-system
ADDRESSES PORT  MATCH                                        DESTINATION
0.0.0.0   8443  SNI: frontend.example-domain.com Route: https.443.https-frontend.tls-gateway.istio-system
0.0.0.0   15021 ALL                                          Inline Route: /healthz/ready*
0.0.0.0   15090 ALL                                          Inline Route: /stats/prometheus*

$ istioctl proxy-config route $(kubectl get pod --selector app=istio-ingressgateway --output jsonpath='{.items[0].metadata.name}' -n istio-system) -n istio-system
NAME                                                  VHOST NAME                                      DOMAINS                                     MATCH                  VIRTUAL SERVICE
https.443.https-frontend.tls-gateway.istio-system     frontend.example-domain.com:443     frontend.example-domain.com     /*                     gateway-vs.app
                                                      backend                                         *                                           /stats/prometheus*
                                                      backend                                         *                                           /healthz/ready*



$ kubectl -n app get po,svc,vs
NAME                                        READY   STATUS    RESTARTS   AGE
pod/backend-deploy-alpha-74b7c6586f-qqwq9   2/2     Running   0          6m37s
pod/backend-deploy-beta-5bf645756c-gzz8h    2/2     Running   0          6m37s
pod/backend-deploy-ga-84d6bcbf54-rbp8f      2/2     Running   0          6m36s
pod/frontend-deploy-6bb757d97f-6ddjz        2/2     Running   0          5m25s

NAME                   TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
service/backend-svc    ClusterIP   192.168.93.120   <none>        5000/TCP   6m36s
service/frontend-svc   ClusterIP   192.168.72.107   <none>        8000/TCP   8m24s

NAME                                            GATEWAYS                       HOSTS                                         AGE
virtualservice.networking.istio.io/backend-vs                                  ["backend-svc"]                               6m36s
virtualservice.networking.istio.io/gateway-vs   ["istio-system/tls-gateway"]   ["frontend.example-domain.com"]   8m24s
```

- Test connectivity
```sh
$ host frontend.example-domain.com
webserver.example-domain.com has address X.Y.Z.W

$ for i in $(seq 1 10); do
    curl -skI https://frontend.example-domain.com
done
The version is beta (nginx:1.23)
The version is beta (nginx:1.23)
The version is beta (nginx:1.23)
The version is beta (nginx:1.23)
The version is alpha (nginx:1.25)
The version is ga (nginx:1.19)
The version is beta (nginx:1.23)
The version is alpha (nginx:1.25)
The version is beta (nginx:1.23)
The version is ga (nginx:1.19)
```

## Canary deployment - traffic splitting
I'm going to  split traffic through the backend versions based on both HTTP header from client and subset percentange between two versions:
- **all** client requests **with** HTTP header `user: foo` set will be routed to version `alpha`
- 80% of client requests **without** HTTP header `user: foo` set will be routed to version `ga`
- 20% of client requests **without** HTTP header `user: foo` set will be routed to version `beta`

```sh
kubectl apply -f application/backend-traffic-splitting.yaml


$ curl -sk https://frontend.example-domain.com/ && echo
done | sort | uniq -c
   2 The version is beta (nginx:1.23)
  18 The version is ga (nginx:1.19)

$ curl -sk -H "user: foo" https://frontend.example-domain.com/ && echo
done | sort | uniq -c
  20 The version is alpha (nginx:1.25)
```
