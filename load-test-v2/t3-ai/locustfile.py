import json, os, random, time, threading
from datetime import datetime, timezone
from locust import HttpUser, task, between, events

MESSAGES = ["요즘 퇴근하고 러닝 시작했어", "주말엔 거의 집에서 넷플릭스 봐", "커피는 산미 있는 원두 좋아해", "고양이 두 마리 키우고 있어", "캠핑 장비 하나씩 모으는 중이야", "향 강한 건 별로 안 좋아해", "요리하는 거 좋아해서 주방용품 욕심 많아", "게임은 닌텐도로 가끔 해", "여행 가면 꼭 그 동네 카페 찾아다녀", "음 잘 모르겠어", "그냥 편한 게 좋아", "최근에 필름카메라에 빠졌어"]
INTERESTS = ["FASHION","BEAUTY","HOME_INTERIOR","COFFEE_TEA","COOKING","GOURMET","TRAVEL","FITNESS","OUTDOOR","GAME","MUSIC","MOVIE_DRAMA","READING","TECH","PET"]
LOCK=threading.Lock()
SEQ=0
PREFIX=int(os.environ.get("ID_PREFIX", "900000000"))
TOKEN=os.environ.get("SERVICE_TOKEN", "")
if not TOKEN: raise RuntimeError("SERVICE_TOKEN is required (do not put it in a file)")
if not (0 <= PREFIX <= 9000000000000000): raise RuntimeError("Invalid ID_PREFIX")

def next_id():
    global SEQ
    with LOCK:
        SEQ+=1
        return PREFIX+SEQ

def utc(): return datetime.now(timezone.utc).isoformat(timespec="seconds")

def report(name, duration_ms, success, code=None, extra=None):
    events.request.fire(request_type="AI", name=name, response_time=duration_ms, response_length=0,
                        exception=None if success else Exception(str(code or 'FAILED')), context=extra or {})

def extract_code(response):
    try: return response.json().get('code',f'HTTP_{response.status_code}')
    except Exception: return f'HTTP_{response.status_code}'

class ConversationUser(HttpUser):
    wait_time=between(0.2, 1.0)
    def on_start(self):
        self.client.headers.update({"Authorization":f"Bearer {TOKEN}", "Content-Type":"application/json"})

    @task
    def conversation(self):
        uid=next_id(); room=uid
        payload={"userId":uid,"conversationRoomId":room,"userProfile":{"nickname":f"테스트유저{uid}","birthDate":"1998-05-12","gender":random.choice(["MALE","FEMALE"]),"interestCategoryCodes":random.sample(INTERESTS, k=random.randint(1,4)),"allergyCodes":[],"giftExclusionCodes":[]}}
        start=time.perf_counter()
        try:
            with self.client.post('/v1/chat/sessions', json=payload, name='session', timeout=90, catch_response=True) as resp:
                ms=(time.perf_counter()-start)*1000
                if resp.status_code!=201:
                    code=extract_code(resp); resp.failure(code); report('session_latency',ms,False,code); return
                resp.success(); report('session_latency',ms,True)
        except Exception as exc:
            report('session_latency',(time.perf_counter()-start)*1000,False,type(exc).__name__); return
        for turn in range(1,13):
            start=time.perf_counter(); ttft=None; completed=None; stream_error=None; status=None
            try:
                # stream=True is essential: record delta arrival before the entire response is consumed.
                with self.client.post(f'/v1/chat/sessions/{room}/messages/stream',json={"userId":uid,"userMessageId":turn,"message":random.choice(MESSAGES)},name='stream',stream=True,timeout=(10,90),catch_response=True) as resp:
                    status=resp.status_code
                    if status!=200:
                        stream_error=extract_code(resp)
                    else:
                        event_type=None; data_lines=[]
                        for raw in resp.iter_lines(chunk_size=1,decode_unicode=True):
                            if raw is None: continue
                            line=raw.decode('utf-8',errors='replace') if isinstance(raw,bytes) else raw
                            if line.startswith(':'): continue
                            if line.startswith('event:'): event_type=line[6:].strip()
                            elif line.startswith('data:'): data_lines.append(line[5:].strip())
                            elif not line.strip():
                                if event_type=='delta' and ttft is None: ttft=(time.perf_counter()-start)*1000
                                if event_type in ('completed','error'):
                                    try: obj=json.loads('\n'.join(data_lines))
                                    except Exception: obj={}
                                    if event_type=='completed': completed=obj
                                    else: stream_error=obj.get('code','SSE_ERROR')
                                    break
                                event_type=None; data_lines=[]
                        if completed is None and stream_error is None: stream_error='MISSING_COMPLETED'
                    if stream_error: resp.failure(str(stream_error))
                    else: resp.success()
                elapsed=(time.perf_counter()-start)*1000
                if stream_error:
                    report('turn_latency',elapsed,False,stream_error); return
                report('turn_latency',elapsed,True)
                if ttft is not None and not completed.get('inputLocked',False): report('ttft',ttft,True)
                if completed.get('inputLocked',False): break
            except Exception as exc:
                report('turn_latency',(time.perf_counter()-start)*1000,False,type(exc).__name__); return
            time.sleep(random.uniform(8,20))
        start=time.perf_counter()
        try:
            with self.client.post(f'/v1/chat/sessions/{room}/analysis',name='analysis',timeout=90,catch_response=True) as resp:
                ms=(time.perf_counter()-start)*1000
                if resp.status_code==422 and extract_code(resp)=='PROFILE_TOO_SPARSE':
                    # Expected content limitation: not a load failure, but not a completed analysis.
                    resp.success(); report('analysis_sparse',ms,True); return
                if not (200<=resp.status_code<300):
                    code=extract_code(resp); resp.failure(code); report('analysis_latency',ms,False,code); return
                resp.success(); report('analysis_latency',ms,True)
                report('conversation_completed',0,True)
        except Exception as exc:
            report('analysis_latency',(time.perf_counter()-start)*1000,False,type(exc).__name__)
