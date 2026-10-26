#!/usr/bin/env python3
"""Run sequential Locust stages; stop after threshold breach; keep per-stage reports."""
import csv, json, os, pathlib, subprocess, sys, time, datetime, shutil
ROOT=pathlib.Path(__file__).resolve().parents[1]
STAGES=[(1,None,0),(5,600,60),(10,600,60),(20,600,120),(30,600,120),(50,600,180)]
LIMITS={'session_latency':8000,'ttft':3000,'turn_latency':12000,'analysis_latency':15000}

def p95(rows,name):
    vals=[float(r['95%']) for r in rows if r.get('Name')==name and r.get('95%')]
    return vals[0] if vals else None

def main():
    if not os.environ.get('SERVICE_TOKEN'): sys.exit('SERVICE_TOKEN required')
    if not os.environ.get('AI_BASE_URL'): sys.exit('AI_BASE_URL required, e.g. http://host:8000')
    if not shutil.which('locust'): sys.exit('Install dependencies: python3 -m pip install -r requirements.txt')
    stamp=datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    run_dir=ROOT/'results'/stamp; run_dir.mkdir(parents=True)
    selected=os.environ.get('STAGES','1,5,10,20,30,50')
    wanted={int(x.strip()) for x in selected.split(',')}
    if wanted-{1,5,10,20,30,50}: sys.exit('STAGES must contain only 1,5,10,20,30,50')
    summary=[]
    for vus,hold,ramp in STAGES:
        if vus not in wanted: continue
        if vus==1:
            duration=int(os.environ.get('SMOKE_SECONDS','180'))
        else:
            duration=hold+ramp
        prefix=run_dir/f'vu-{vus}'
        start=datetime.datetime.now(datetime.timezone.utc).isoformat(timespec='seconds')
        cmd=['locust','-f',str(ROOT/'locustfile.py'),'--headless','--host',os.environ['AI_BASE_URL'].rstrip('/'),'-u',str(vus),'-r',str(max(1,vus/ramp if ramp else 1)),'--run-time',f'{duration}s','--stop-timeout','90','--csv',str(prefix),'--csv-full-history','--only-summary']
        env=os.environ.copy(); env['ID_PREFIX']=str(int(os.environ.get('ID_PREFIX_BASE','900000000'))+int(stamp[-7:-1].replace('T','0') if False else time.time())%1000000*1000+vus*10000000)
        print(f'\nSTART VU={vus} UTC={start} duration={duration}s',flush=True)
        with open(str(prefix)+'.log','w') as log:
            proc=subprocess.run(cmd,env=env,stdout=log,stderr=subprocess.STDOUT)
        end=datetime.datetime.now(datetime.timezone.utc).isoformat(timespec='seconds')
        stat_file=pathlib.Path(str(prefix)+'_stats.csv')
        rows=list(csv.DictReader(stat_file.open())) if stat_file.exists() else []
        aggregate=next((r for r in rows if r.get('Name')=='Aggregated'),{})
        total=int(aggregate.get('Request Count') or 0)
        fails=int(aggregate.get('Failure Count') or 0)
        rate=(fails/total*100) if total else 100.0
        metrics={name:p95(rows,name) for name in LIMITS}
        # Locust CSV names may use numeric headers (e.g. '95%').
        passed=(proc.returncode==0 and total>0 and rate<=1 and all(metrics[n] is not None and metrics[n]<=limit for n,limit in LIMITS.items()))
        record={'vus':vus,'start_utc':start,'end_utc':end,'requests':total,'failures':fails,'error_percent':round(rate,3),'p95_ms':metrics,'pass':passed,'exit_code':proc.returncode}
        summary.append(record)
        (run_dir/'summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2))
        print(json.dumps(record,ensure_ascii=False),flush=True)
        if not passed:
            print('STOP: stage did not meet criteria. Inspect CSV/log and confirm with AI team.',flush=True)
            break
    print(f'RESULTS: {run_dir}')

if __name__=='__main__': main()
