local k = import 'ksonnet/ksonnet.beta.3/k.libsonnet';
local service = k.core.v1.service;
local servicePort = k.core.v1.service.mixin.spec.portsType;


{
  _config+:: {
    versions+:: {
      thanos: 'v0.1.0',
    },
    imageRepos+:: {
      thanos: 'improbable/thanos',
    },
  },
  prometheus+:: {
    prometheus+: {
      spec+: {
        podMetadata+: {
          labels+: { 'thanos-peer': 'true' },
        },
        thanos+: {
          peers: 'thanos-peers.' + $._config.namespace + '.svc:10900',
          version: $._config.versions.thanos,
          baseImage: $._config.imageRepos.thanos,
	        gcs+: {
	          bucket: $._config.thanos.bucket,
	          credentials+: {
	            key: $._config.thanos.credentials.key,
	            name: $._config.thanos.credentials.name,
	          },
	        },
        },
      },
    },
    thanosStoreDeployment:
      local deployment = k.apps.v1beta2.deployment;
      local container = deployment.mixin.spec.template.spec.containersType;
      local containerPort = container.portsType;
      local volume = deployment.mixin.spec.template.spec.volumesType;
      local containerVolumeMount = container.volumeMountsType;
      local storageVolumeName = 'thanos-storage';
      local storageVolume = volume.fromHostPath(storageVolumeName, '/data/storage/thanos');
      local storageVolumeMount = containerVolumeMount.new(storageVolumeName, '/var/thanos/store');
      local secretVolumeName = 'secret-gcs-credentials';
      local secretSecretName = 'gcs-credentials';
      local secretVolume = volume.withName(secretVolumeName) + volume.mixin.secret.withSecretName(secretSecretName).withDefaultMode(420);
      local secretVolumeMount = containerVolumeMount.new(secretVolumeName, '/var/run/secrets/prometheus.io/' + $._config.thanos.credentials.name).withReadOnly(true);
      local env = container.envType;
      local volumes = [storageVolume, secretVolume];
      local volumeMounts = [storageVolumeMount, secretVolumeMount];

      local thanosStoreContainer =
        container.new('thanos-store', $._config.imageRepos.thanos + ':' + $._config.versions.thanos) +
        container.withPorts([
          containerPort.newNamed('http', 10902),
          containerPort.newNamed('grpc', 10901),
          containerPort.newNamed('cluster', 10900),
        ]) +
        container.withVolumeMounts(volumeMounts) +
        container.withEnv(env.new('GOOGLE_APPLICATION_CREDENTIALS', '/var/run/secrets/prometheus.io/' + $._config.thanos.credentials.name + '/' + $._config.thanos.credentials.key)) +
        container.withArgs([
          'store',
          '--log.level=debug',
          '--cluster.peers=thanos-peers.' + $._config.namespace + '.svc:10900',
	        '--gcs.bucket=' + $._config.thanos.bucket,
	        '--data-dir=/var/thanos/store',
        ]);
      local podLabels = { app: 'thanos-store', 'thanos-peer': 'true' };
      deployment.new('thanos-store', 1, thanosStoreContainer, podLabels) +
      deployment.mixin.metadata.withNamespace($._config.namespace) +
      deployment.mixin.spec.template.spec.withVolumes(volumes) +
      //statefulSet.mixin.spec.withVolumeClaimTemplates([]) +
      deployment.mixin.metadata.withLabels(podLabels) +
      deployment.mixin.spec.selector.withMatchLabels(podLabels) +
      //deployment.mixin.spec.template.spec.securityContext.withFsGroup(2000) +
      //deployment.mixin.spec.template.spec.securityContext.withRunAsNonRoot(true) +
      //deployment.mixin.spec.template.spec.securityContext.withRunAsUser(1000) +
      deployment.mixin.spec.template.spec.withServiceAccountName('prometheus-' + $._config.prometheus.name),
    thanosCompactorDeployment:
      local deployment = k.apps.v1beta2.deployment;
      local container = deployment.mixin.spec.template.spec.containersType;
      local containerPort = container.portsType;
      local volume = deployment.mixin.spec.template.spec.volumesType;
      local containerVolumeMount = container.volumeMountsType;
      local storageVolumeName = 'thanos-compactor';
      local storageVolume = volume.fromHostPath(storageVolumeName, '/data/storage/thanos-compactor');
      local storageVolumeMount = containerVolumeMount.new(storageVolumeName, '/var/thanos/store');
      local secretVolumeName = 'secret-gcs-credentials';
      local secretSecretName = 'gcs-credentials';
      local secretVolume = volume.withName(secretVolumeName) + volume.mixin.secret.withSecretName(secretSecretName).withDefaultMode(420);
      local secretVolumeMount = containerVolumeMount.new(secretVolumeName, '/var/run/secrets/prometheus.io/' + $._config.thanos.credentials.name).withReadOnly(true);
      local env = container.envType;
      local volumes = [storageVolume, secretVolume];
      local volumeMounts = [storageVolumeMount, secretVolumeMount];

      local thanosCompactorContainer =
        container.new('thanos-compactor', $._config.imageRepos.thanos + ':' + $._config.versions.thanos) +
        container.withPorts([
          containerPort.newNamed('http', 10902),
        ]) +
        container.mixin.resources.withRequests({ cpu: '1000m', memory: '1000Mi' }) +
        container.mixin.resources.withLimits({ cpu: '1000m', memory: '1000Mi' }) +
        container.withVolumeMounts(volumeMounts) +
        container.withEnv(env.new('GOOGLE_APPLICATION_CREDENTIALS', '/var/run/secrets/prometheus.io/' + $._config.thanos.credentials.name + '/' + $._config.thanos.credentials.key)) +
        container.withArgs([
          'compact',
          '--log.level=debug',
	        '--gcs.bucket=' + $._config.thanos.bucket,
	        '--data-dir=/var/thanos/store',
          '--retention.resolution-raw=2d',
          '--retention.resolution-5m=2d',
          '--retention.resolution-1h=2d',
          '--wait',
        ]);
      local podLabels = { app: 'thanos-compactor' };
      deployment.new('thanos-compactor', 1, thanosCompactorContainer, podLabels) +
      deployment.mixin.metadata.withNamespace($._config.namespace) +
      deployment.mixin.spec.template.spec.withVolumes(volumes) +
      deployment.mixin.metadata.withLabels(podLabels) +
      deployment.mixin.spec.selector.withMatchLabels(podLabels) +
      deployment.mixin.spec.template.spec.withServiceAccountName('prometheus-' + $._config.prometheus.name),
    thanosQueryDeployment:
      local deployment = k.apps.v1beta2.deployment;
      local container = k.apps.v1beta2.deployment.mixin.spec.template.spec.containersType;
      local containerPort = container.portsType;

      local thanosQueryContainer =
        container.new('thanos-query', $._config.imageRepos.thanos + ':' + $._config.versions.thanos) +
        container.withPorts([
          containerPort.newNamed('http', 10902),
          containerPort.newNamed('grpc', 10901),
          containerPort.newNamed('cluster', 10900),
        ]) +
        container.withArgs([
          'query',
          '--log.level=debug',
          '--query.replica-label=prometheus_replica',
          '--cluster.peers=thanos-peers.' + $._config.namespace + '.svc:10900',
        ]);
      local podLabels = { app: 'thanos-query', 'thanos-peer': 'true' };
      deployment.new('thanos-query', 1, thanosQueryContainer, podLabels) +
      deployment.mixin.metadata.withNamespace($._config.namespace) +
      deployment.mixin.metadata.withLabels(podLabels) +
      deployment.mixin.spec.selector.withMatchLabels(podLabels) +
      deployment.mixin.spec.template.spec.withServiceAccountName('prometheus-' + $._config.prometheus.name),
    thanosQueryService:
      local thanosQueryPort = [servicePort.newNamed('http-query', 9090, 'http') + servicePort.withNodePort(30901)];
      service.new('thanos-query', { app: 'thanos-query' }, thanosQueryPort) +
      service.mixin.spec.withType('NodePort') +
      service.mixin.metadata.withNamespace($._config.namespace) +
      service.mixin.metadata.withLabels({ app: 'thanos-query' }),
    thanosPeerService:
      local thanosPeerPort = servicePort.newNamed('cluster', 10900, 'cluster');
      service.new('thanos-peers', { 'thanos-peer': 'true' }, thanosPeerPort) +
      service.mixin.metadata.withNamespace($._config.namespace) +
      service.mixin.spec.withType('ClusterIP') +
      service.mixin.spec.withClusterIp('None'),

  },
}
