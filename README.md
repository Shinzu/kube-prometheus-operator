# Prometheus Operator deploy

## Prerequisites
```
go get github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb
go get github.com/google/go-jsonnet/jsonnet
go get -v github.com/brancz/gojsontoyaml
```

## Init and update

```
jb init
jb install github.com/coreos/prometheus-operator/contrib/kube-prometheus/jsonnet/kube-prometheus
```

update if needed
```
jb update
```

## Build

```
./build.sh kube-prom.jsonnet
```
