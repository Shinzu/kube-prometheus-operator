local kp = 
(import 'kube-prometheus/kube-prometheus.libsonnet') + 
(import 'kube-prometheus/kube-prometheus-kubeadm.libsonnet') +
(import 'kube-prometheus/kube-prometheus-node-ports.libsonnet') +
(import 'kube-prometheus/kube-prometheus-thanos.libsonnet') +
{
  _config+:: {
    namespace: 'monitoring',
    thanos+:: {
      bucket: 'thanos-1538568885439-thanos-storage',
      credentials+:: {
        key: 'thanos-storage-creds.json',
        name: 'gcs-credentials',
      },
    },
  },
  prometheus+: {
    kubeDnsPrometheusDiscoveryService:
      local k = import 'ksonnet/ksonnet.beta.3/k.libsonnet';
      local service = k.core.v1.service;
      local servicePort = k.core.v1.service.mixin.spec.portsType;

      service.new('coredns-prometheus-discovery', { 'k8s-app': 'kube-dns' }, [servicePort.newNamed('http-metrics', 9153, 9153) + servicePort.withProtocol('TCP')]) +
      service.mixin.spec.withType('ClusterIP') +
      service.mixin.metadata.withNamespace('kube-system') +
      service.mixin.metadata.withLabels({'k8s-app': 'coredns', 'component': 'metrics'}) +
      service.mixin.spec.withClusterIp('None'),
  },
};

{ ['00namespace-' + name]: kp.kubePrometheus[name] for name in std.objectFields(kp.kubePrometheus) } +
{ ['0prometheus-operator-' + name]: kp.prometheusOperator[name] for name in std.objectFields(kp.prometheusOperator) } +
{ ['node-exporter-' + name]: kp.nodeExporter[name] for name in std.objectFields(kp.nodeExporter) } +
{ ['kube-state-metrics-' + name]: kp.kubeStateMetrics[name] for name in std.objectFields(kp.kubeStateMetrics) } +
{ ['alertmanager-' + name]: kp.alertmanager[name] for name in std.objectFields(kp.alertmanager) } +
{ ['prometheus-' + name]: kp.prometheus[name] for name in std.objectFields(kp.prometheus) } +
{ ['grafana-' + name]: kp.grafana[name] for name in std.objectFields(kp.grafana) }
