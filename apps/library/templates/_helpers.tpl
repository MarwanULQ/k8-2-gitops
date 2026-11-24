{{- define "library.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "library.labels" -}}
app.kubernetes.io/name: {{ include "library.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{- end }}

{{- define "library.appName" -}}flask-webapp{{- end }}
{{- define "library.postgresName" -}}postgres{{- end }}
{{- define "library.configName" -}}library-config{{- end }}
{{- define "library.secretsName" -}}library-secrets{{- end }}
{{- define "library.pullSecretName" -}}ghcr-pull-secret{{- end }}
{{- define "library.migrateName" -}}library-migrate{{- end }}
