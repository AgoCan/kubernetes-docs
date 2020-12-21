# operator

```
kubectl apply -f https://download.elastic.co/downloads/eck/1.3.1/all-in-one.yaml
```

```
kubectl -n elastic-system logs -f statefulset.apps/elastic-operator
```

- https://artifacthub.io/packages/olm/community-operators/elastic-cloud-eck
- https://www.elastic.co/guide/en/cloud-on-k8s/1.3/k8s-deploy-eck.html
- https://www.elastic.co/guide/en/cloud-on-k8s/1.3/k8s-operating-eck.html
