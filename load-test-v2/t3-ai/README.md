# t3-ai — AI chat / RunPod load test

AI팀 2026-10-23 요청서에 맞춘 독립 Locust 시나리오. **AI 서버**를 대상으로 호출하며 RunPod를 직접 호출하지 않습니다.

## 설치 (macOS)

```bash
cd ~/Desktop/KTB4-4th-CLOUD/load-test-v2
# 내려받은 t3-ai 폴더를 이 위치에 압축 해제
cd t3-ai
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## 실행

AI팀과 대상 AI 서버의 주소, SERVICE_TOKEN, RunPod 준비 및 OpenRouter 폴백 비활성화를 확인하세요. 토큰을 명령행이나 채팅에 노출하지 마세요.

```bash
export AI_BASE_URL='http://AI-SERVER-HOST:8000'
# 비밀 토큰은 실행 중 프롬프트에서 입력
STAGES=1 ./scripts/run.sh
# smoke 통과 후 전체 단계 (약 1시간 이상)
./scripts/run.sh
```

`AI_BASE_URL`은 `/v1/chat` 없는 **AI 서버 루트**입니다. `SERVICE_TOKEN`은 스크립트가 숨김 입력받습니다. 스테이징인지 프로덕션인지 반드시 AI팀과 확인하세요. `ID_PREFIX_BASE`는 회차별로 변경 가능하며 스크립트도 실행 시각과 단계로 ID를 분리합니다. 동일 시간대에 여러 생성기를 실행한다면 생성기마다 `ID_PREFIX_BASE`를 다르게 지정하세요.

## 설계

- 1 VU smoke (기본 180초; `SMOKE_SECONDS`로 변경), 5/10/20/30/50 VU, 1~3분 램프업 + 10분 유지
- 각 VU는 새 고유 세션 생성 → SSE 최대 12턴 → 분석 → 반복
- 8~20초 think time, 무작위 메시지/관심사, 422 PROFILE_TOO_SPARSE는 정상 예외로 별도 집계
- 409 TURN_IN_PROGRESS/SESSION_EXISTS는 실패로 기록
- 결과: `results/<UTC>/vu-*_stats.csv`, `vu-*_failures.csv`, `vu-*.log`, `summary.json`
- 통과 기준: TTFT p95 ≤3초(마지막 inputLocked 턴 제외), 턴 p95 ≤12초, 세션 p95 ≤8초, 분석 p95 ≤15초, 오류율 ≤1%
- 첫 `delta`를 읽은 시각 기준 TTFT 측정. 서버 SSE의 `completed`까지 시간 기록.

## 유의사항

- `close`는 포함하지 않습니다. RunPod 한계 측정에 집중합니다.
- 1 VU smoke는 180초 내에 분석까지 완료되지 않으면 다음 단계로 넘어가지 않습니다. 필요하면 `SMOKE_SECONDS=600`으로 늘리세요.
- `--stop-timeout 90`이므로 실행 종료가 설정 시간보다 늦어질 수 있습니다.
- Locust의 표준 CSV는 `request_type/name`별 p50/p95/p99, 실패 정보를 기록합니다. `conversation_completed`는 완주 건수의 보조 지표입니다.
- **검증 필요:** AI 서버 SSE가 프록시에서 버퍼링되는지, 서버가 200 이외의 성공 코드를 반환하는지, `analysis`가 실제로 2xx를 반환하는지, 서버 측 TTFT 및 생성기 CPU/네트워크는 별도로 확인해야 합니다.
- 5분 단위 CPU/네트워크 수집 및 각 단계의 정밀한 완주율 분모 집계는 아직 자동화되지 않았습니다. 이 패키지는 클라이언트 요청 메트릭을 우선 제공합니다.
- `results/`에는 사용자/서버 정보가 포함될 수 있으니 공개 저장소에 커밋하지 마세요.
