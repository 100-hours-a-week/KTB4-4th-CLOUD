# NeedU V3 Production Grafana Dashboard

Amazon Managed Service for Prometheus(AMP)에 수집된 V3 Production EKS 지표를 조회하는 운영 대시보드입니다. 이 디렉터리는 AWS 리소스를 생성하지 않으며, Amazon Managed Grafana에 가져올 Dashboard JSON을 코드로 관리합니다.

## 가져오기

1. Amazon Managed Grafana에서 **Dashboards → New → Import**를 엽니다.
2. `dashboards/needu-v3-prod-kubernetes-overview.json`을 업로드합니다.
3. `DS_PROMETHEUS`에 V3 Production AMP 데이터소스를 지정합니다.
4. 폴더와 UID를 확인한 뒤 **Import**를 선택합니다.

같은 UID(`needu-v3-prod-k8s`)의 대시보드가 있으면 덮어쓰기로 반영합니다.

## 제공 패널

- Node Ready·NotReady 상태와 Node Group별 Node 수
- Node CPU·Memory 사용률
- Pending Pod와 Namespace별 Running Pod 수
- Deployment 목표·가용·Unavailable Replica
- Pod CPU·Memory, 재시작, CrashLoopBackOff 상태
- HPA 현재·최소·최대 Replica

Namespace·Deployment·Pod·Node 변수를 사용해 조회 범위를 좁힐 수 있습니다.

## 현재 수집 범위와 후속 작업

현재 ADOT은 kube-state-metrics의 Deployment·Pod·Node 지표와 kubelet cAdvisor 자원 지표를 AMP로 전송합니다.

- HPA 패널은 kube-state-metrics 수집 대상에 `horizontalpodautoscalers`를 추가한 뒤 값이 표시됩니다. 이 변경은 GitOps 모니터링 수집 설정에서 진행해야 합니다.
- HTTP 요청 수·응답 시간·오류율은 애플리케이션 Prometheus 지표가 아직 수집되지 않아 포함하지 않았습니다. 애플리케이션 메트릭 엔드포인트와 ADOT scrape 설정이 필요합니다.
- Cluster Autoscaler 내부 이벤트 지표는 현재 수집하지 않습니다. 대신 Pending Pod와 Node Group별 Node 수로 확장 결과를 확인합니다.

## 로컬 검증

```bash
jq -e '
  .uid == "needu-v3-prod-k8s" and
  (.panels | length > 0) and
  (.templating.list | length >= 4)
' dashboards/needu-v3-prod-kubernetes-overview.json
```
