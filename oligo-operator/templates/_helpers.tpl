{{/*
Expand the name of the chart.
*/}}
{{- define "oligo-operator.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "oligo-operator.tag" -}}
{{- default .Chart.AppVersion .Values.controllerManager.manager.image.tag -}}
{{- end -}}

{{- define "fluentBitConfigVolumeMounts" -}}
{{- if index .Values "fluent-bit" "enabled" }}
- mountPath: /fluent-bit-template.conf
  name: fluent-bit-config-template
  subPath: fluent-bit.conf
- mountPath: /conf
  name: fluent-bit-config
{{- end }}
{{- end }}

{{- define "fluentBitEnv" -}}
{{- if index .Values "fluent-bit" "enabled" }}
- name: NAMESPACE
  valueFrom:
    fieldRef:
      fieldPath: metadata.namespace
- name: POD_ID
  valueFrom:
    fieldRef:
      fieldPath: metadata.uid
- name: POD_NAME
  valueFrom:
    fieldRef:
      fieldPath: metadata.name
- name: CONTAINER_NAME
  value: {{ .containerName }}
{{- end }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "oligo-operator.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "oligo-operator.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}


{{/*
Secrets
*/}}
{{- define "oligo-operator.imagePullSecretName" -}}
{{- default (printf "%s-imagepullkey" (include "oligo-operator.fullname" .)) .Values.imagePullSecret.name -}}
{{- end -}}

{{- define "oligo-operator.imagePullSecretValue" -}}
{{- $format := "{\"auths\": {\"%s\": {\"auth\": \"%s\"}}}" -}}
{{- $creds := printf "%s:%s" (required "A valid username for image pull secret required" .Values.imagePullSecret.username) .Values.imagePullSecret.password -}}
{{- printf $format "docker.io" (b64enc $creds) | b64enc -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "oligo-operator.labels" -}}
helm.sh/chart: {{ include "oligo-operator.chart" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
oligo/app: operator
oligo/donotscan: "enabled"
{{- range $key, $value := .Values.commonLabels }}
{{ $key }}: {{ $value | quote }}
{{- end }}
{{- end }}

{{/*
Tolerations
*/}}
{{- define "oligo-operator.tolerations" -}}
{{- with .Values.controllerManager.tolerations }}
{{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "oligo-operator.selectorLabels" -}}
app.kubernetes.io/name: {{ include "oligo-operator.name" . }}
app.kubernetes.io/instance: {{ .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "oligo-operator.serviceAccountName" -}}
{{- printf "%s-%s" (include "oligo-operator.fullname" .) "sa" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "oligo-operator.deploymentName" -}}
{{- printf "%s-%s" (include "oligo-operator.fullname" .) "deployment" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "oligo-operator.leaderElectionRoleName" -}}
{{- printf "%s-%s" (include "oligo-operator.fullname" .) "leader-election-role" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "oligo-operator.leaderElectionRoleBindingName" -}}
{{- printf "%s-%s" (include "oligo-operator.fullname" .) "leader-election-role-binding" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "oligo-operator.managerRole" -}}
{{- printf "%s-%s" (include "oligo-operator.fullname" .) "manager-role" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "oligo-operator.managerRoleBinding" -}}
{{- printf "%s-%s" (include "oligo-operator.fullname" .) "manager-role-binding" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "oligo-operator.metricsReaderClusterRole" -}}
{{- printf "%s-%s" (include "oligo-operator.fullname" .) "metrics-reader-cluster-role" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "oligo-operator.metricsServiceName" -}}
{{- printf "%s-%s" (include "oligo-operator.fullname" .) "metrics-service" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "oligo-operator.proxyClusterRole" -}}
{{- printf "%s-%s" (include "oligo-operator.fullname" .) "proxy-cluster-role" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "oligo-operator.proxyClusterRoleBinding" -}}
{{- printf "%s-%s" (include "oligo-operator.fullname" .) "proxy-cluster-role-binding" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "oligo-operator.sensorOverridesConfigmap" -}}
{{- printf "%s-%s" (include "oligo-operator.fullname" .) "override" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "oligo-operator.sensorOverridesConfigmapHash" -}}
{{- .Values.sensorOverrides | toJson | sha256sum -}}
{{- end }}

{{/* Sensor RBAC */}}

{{/* Scanner */}}
# Take override from .Values.sensorRbac.serviceAccount.scanner
{{- define "scanner.serviceAccountName" -}}
{{- .Values.sensorRbac.serviceAccount.scanner | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "scanner.clusterRoleName" -}}
{{- printf "%s-%s" (include "oligo-operator.fullname" .) "scanner" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "scanner.clusterRoleBindingName" -}}
{{- printf "%s-%s" (include "oligo-operator.fullname" .) "scanner" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Fluent-bit */}}
# Take override from .Values.sensorRbac.serviceAccount.fluent-bit
{{- define "fluent-bit.serviceAccountName" -}}
{{- index .Values "sensorRbac" "serviceAccount" "fluent-bit" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "fluent-bit.clusterRoleName" -}}
{{- printf "%s-%s" (include "oligo-operator.fullname" .) "fluent-bit" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "fluent-bit.clusterRoleBindingName" -}}
{{- printf "%s-%s" (include "oligo-operator.fullname" .) "fluent-bit" | trunc 63 | trimSuffix "-" }}
{{- end }}


{{/* Sensor */}}
# Take override from .Values.sensorRbac.serviceAccount.sensor
{{- define "sensor.serviceAccountName" -}}
{{- .Values.sensorRbac.serviceAccount.sensor | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "sensor.clusterRoleName" -}}
{{- printf "%s-%s" (include "oligo-operator.fullname" .) "sensor" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "sensor.clusterRoleBindingName" -}}
{{- printf "%s-%s" (include "oligo-operator.fullname" .) "sensor" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "commonEnvVars" -}}
- name: OLIGO_API_KEY
  valueFrom:
    secretKeyRef:
      name: "{{ .Values.controllerManager.gateway.apiKeySecretName }}"
      key: "apikey"
- name: NODE_NAME
  valueFrom:
    fieldRef:
      fieldPath: spec.nodeName
{{- if .Values.httpsProxyConfiguration.enabled }}
- name: HTTPS_PROXY
  value: {{ .Values.httpsProxyConfiguration.url }}
- name: HTTP_PROXY # Fluent Bit supports configuring an HTTP proxy for all egress HTTP/HTTPS traffic via the HTTP_PROXY environment variable.
  value: {{ .Values.httpsProxyConfiguration.url }}
- name: NO_PROXY
  value: {{ .Values.httpsProxyConfiguration.noProxy }}
{{- end }}
{{- end }}


{{- define "oligo-operator.configMapName" -}}
{{- printf "%s-%s" .Release.Name "operator-config" }}
{{- end -}}


{{- define "oligo-operator.configMapVolume" -}}
- name: operator-config
  configMap:
    name: {{ include "oligo-operator.configMapName" . }}
{{- end -}}

{{- define "oligo-operator.configFileName" -}}
config.yaml
{{- end -}}

{{- define "oligo-operator.configMapVolumeMounts" -}}
- name: operator-config
  mountPath: /dist/{{ include "oligo-operator.configFileName" . }}
  subPath: {{ include "oligo-operator.configFileName" . }}
{{- end -}}

{{- define "oligo-operator.configMapAnnotations" -}}
checksum/{{- include "oligo-operator.configFileName" . -}}: {{ include (print $.Template.BasePath "/config/operatorconfig.yaml") . | sha256sum }}
{{- end -}}
