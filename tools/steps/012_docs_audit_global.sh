#!/usr/bin/env bash
set -euo pipefail

mkdir -p tools/logs
TS="$(date +%Y%m%d_%H%M%S)"
OUT="tools/logs/docs_audit_global_${TS}.txt"

python3 - <<'PY' | tee "$OUT" >/dev/null
import os,re,sys,datetime
root='.'
files=sorted([f for f in os.listdir(root) if f.endswith('.md') and os.path.isfile(f)])
print(f"Global Doc Audit — {datetime.datetime.now().isoformat()}\n")
print("FILES:")
for f in files:
    print(f"- {f}")
print()

exists=set(files)
# helpers
H=re.compile(r'^(?P<hash>#{1,6})\s*(?P<title>.+?)\s*$', re.M)
LINK=re.compile(r'\[[^\]]+\]\(([^)]+)\)')
PORTS_EXPECTED={"8000","3000"}
ENDPOINTS=["/health","/submissions/upload_zip","/rag/query"]

def headings(text):
    return [(m.start(),m.group('hash'),m.group('title')) for m in H.finditer(text)]

print("FINDINGS:")
fix_plan=[]
step=13

# helper to note step
seen_steps=set()

def plan(s):
    global step
    if s in seen_steps: return
    print_end=''  # no-op here
    fix_plan.append((step,s))
    seen_steps.add(s)
    step+=1

for f in files:
    with open(f,encoding='utf-8',errors='replace') as fh:
        t=fh.read()
    fnd=[]
    # 0) specific filename typo
    if f=="SECURITYY.md":
        fnd.append("FILENAME_TYPO: SECURITYY.md (suggest SECURITY.md)")
        plan("rename SECURITYY.md -> SECURITY.md")
    # 1) required sections
    req_map={
        'README.md':[r'Installation',r'Run',r'Endpoints?',r'Ports?',r'Architecture'],
        'DEPLOYMENT.md':[r'Prerequisites',r'Local',r'(Prod|Server)',r'Rollback'],
        'OPERATIONS.md':[r'Runbook',r'Logs',r'Incidents'],
    }
    if f.startswith('SECURITY') or f.startswith('SECURITYY'):
        req_map[f]=[r'Threat model',r'Secrets',r'(Vuln|Vulnerability) reporting']
    req=req_map.get(f,[])
    if req:
        miss=[]
        for pat in req:
            if not re.search(rf'^##\s*{pat}\b', t, re.I|re.M):
                miss.append(pat)
        if miss:
            fnd.append("MISSING_SECTIONS: "+", ".join(miss))
            plan(f"add sections in {f}")
    # 2) duplicate headings
    hs=[title.strip().lower() for _,_,title in headings(t)]
    from collections import Counter
    cnt=Counter(hs)
    dups=[k for k,c in cnt.items() if c>1]
    if dups:
        fnd.append("DUPLICATE_HEADINGS: "+", ".join(sorted(dups)))
        plan(f"dedupe headings in {f}")
    # 3) empty sections
    idx=[m.start() for m in H.finditer(t)]
    idx.append(len(t))
    empties=[]
    titles=[m.group('title').strip() for m in H.finditer(t)]
    hs_iter=list(H.finditer(t))
    for i in range(len(hs_iter)):
        start=hs_iter[i].end()
        end=hs_iter[i+1].start() if i+1<len(hs_iter) else len(t)
        body=t[start:end]
        lines=[ln for ln in body.splitlines() if ln.strip() and not ln.strip().startswith('#')]
        if not lines:
            empties.append(titles[i])
    if empties:
        fnd.append("EMPTY_SECTIONS: "+", ".join(empties))
        plan(f"fill empty sections in {f}")
    # 4) ports
    ports=set()
    for m in re.finditer(r'(?i)port\s*[:=]?\s*(\d{2,5})', t):
        ports.add(m.group(1))
    for m in re.finditer(r':\s*(\d{2,5})\b', t):
        ports.add(m.group(1))
    unexpected=sorted(p for p in ports if p not in PORTS_EXPECTED)
    if unexpected:
        fnd.append("PORT_UNEXPECTED: "+", ".join(unexpected))
        plan(f"normalize ports in {f}")
    # 5) endpoints presence (report missing expected ones for README/ARCHITECTURE/SPEC/RAG)
    if f in ("README.md","ARCHITECTURE.md","SPEC.md","RAG.md"):
        miss=[e for e in ENDPOINTS if not re.search(re.escape(e)+r'\b', t)]
        if miss:
            fnd.append("ENDPOINTS_MISSING: "+", ".join(miss))
            plan(f"document endpoints in {f}")
    # 6) broken internal links
    broken=[]
    for link in LINK.findall(t):
        if link.lower().endswith('.md'):
            target=os.path.basename(link)
            if target not in exists:
                broken.append(link)
                plan(f"update links in {f}")
    if broken:
        fnd.append("BROKEN_LINKS: "+", ".join(broken))
    print(f"FILE: {f}")
    if fnd:
        for it in fnd:
            print(f"- {it}")
    else:
        print("- OK: none")
    print()

print("FIX_PLAN:")
for n,s in fix_plan:
    print(f"- Step {n:03d}: {s}")
PY

echo "REPORT=$OUT" >> "$OUT"
