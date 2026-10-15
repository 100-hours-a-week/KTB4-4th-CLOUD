# V1 Staging → V2 Staging: 1차 Cutover k6

## 범위
- `staging.needu.gift`로 GET 요청만 전송; 총 10 RPS, 기본 20분.
- 친구 목록/상세, 개인 추천, 선물 추천을 1요청/iteration으로 순환.
- 기존 JWT 20개 사용. 로그인·쓰기·DB 변경·DNS 변경은 수행하지 않음.
- 응답 HTTP 200 및 JSON 형식 확인, 상태 코드/지연/실패와 T0~T8 비교.

## 시작
```bash
cd v2-migration/k6
brew install k6
cp data/users.example.json data/users.json
# users.json에 실제 20개 계정의 JWT 및 조회 가능한 friendUserId/giftUserId 입력
RATE=2 DURATION=1m LOG_REQUESTS=true ./scripts/run.sh
RATE=10 DURATION=20m LOG_REQUESTS=true ./scripts/run.sh
```

**중요:** `users.example.json`은 구조 예시 1개만 제공한다. `users.json`에는 반드시 20개 계정을 입력해야 한다. 토큰은 Git에 커밋하지 않는다. 실제 서비스가 Bearer JWT를 사용하는지, GET 응답이 JSON인지, GET 호출이 부작용이 없는지 Smoke Test에서 확인한다.

## T0~T8 이벤트 기록
```bash
# 별도 터미널에서 각 실제 이벤트 발생 시 실행
./scripts/mark-phase.sh T0 'V1 Write Freeze 시작'
./scripts/mark-phase.sh T1 '진행 중 Transaction 종료'
./scripts/mark-phase.sh T2 'CDC 동기화 완료'
./scripts/mark-phase.sh T3 '정합성 검증 및 DMS 중지'
./scripts/mark-phase.sh T4 '사용자 데이터 변환 완료'
./scripts/mark-phase.sh T5 'V2 Backend healthy'
./scripts/mark-phase.sh T6 'V2 읽기 Smoke Test 완료'
./scripts/mark-phase.sh T7 'Route 53 변경'
./scripts/mark-phase.sh T8 'V2 ALB 유입 확인'
```
`results/phases.tsv`에 UTC 시각 저장. `T8 - T0`은 V2 유입 확인까지 걸린 시간이며 V2 쓰기 재개까지의 시간은 아니다.

## 결과
- `k6/results/<UTC 실행시각>/metrics.jsonl`: k6 원시 지표 (API별 tags, 시간 포함)
- `k6/results/<UTC 실행시각>/console.log`: 오류 및 `LOG_REQUESTS=true`인 경우 요청 로그
- `k6/results/<UTC 실행시각>/summary-export.json`: 요약
- `k6/results/<UTC 실행시각>/results/summary.json`: k6 handleSummary 출력
- `k6/results/phases.tsv`: T0~T8 이벤트 기록

**주의:** 기본 실행은 JSONL 로컬 저장 방식. Grafana/Prometheus remote-write 연동은 별도 수신기 설정 후 k6의 `experimental-prometheus-rw` 출력을 사용해야 한다. 이 스크립트는 DMS/PG 정합성을 직접 검증하지 않는다. T8 이후 모든 트래픽이 V2로 갔는지는 k6만으로 증명할 수 없으므로 V1 Nginx/V2 ALB 로그와 DNS 조회 결과를 대조한다. DNS TTL=0과 연결 재사용 해제는 k6 관측을 위한 설정으로 실제 브라우저 DNS 캐시를 재현하지 않는다. 10 RPS는 요청 목표치이므로 dropped_iterations=0 및 http_reqs 수치를 확인한다.
