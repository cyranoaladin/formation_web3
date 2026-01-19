#!/usr/bin/env bash
set -euo pipefail

mkdir -p tools/logs
TS="$(date +%Y%m%d_%H%M%S)"
LOG="tools/logs/docs_fix_rag_${TS}.txt"

sha() { sha256sum "$1" | awk '{print $1}'; }

pre=$(sha RAG.md)
echo "PRE RAG.md ${pre}" | tee "$LOG" >/dev/null

# Déduplication de sections cibles dans RAG.md (idempotent)
python3 -c 'import sys,re,collections
p="RAG.md"
with open(p,encoding="utf-8") as f:
    t=f.read()

def norm(s):
    s=s.strip().lower()
    s=s.replace("\u2013","-").replace("\u2014","-")
    s=re.sub(r"\s+"," ",s)
    return s

keys=["backend","objectif","endpoint","règles","objets indexés","rag - retrieval augmented generation"]
keys=[norm(k) for k in keys]
pat=re.compile(r"(?m)^(#{1,6})\s*(.+?)\s*$")
ms=list(pat.finditer(t))
spans=[]; n=len(t)
for i,m in enumerate(ms):
    hs,he=m.span(); title=m.group(2)
    nxt=ms[i+1].start() if i+1<len(ms) else n
    spans.append((hs,he,nxt,title))

def ntitle(x):
    return norm(x.replace("\u2013","-").replace("\u2014","-"))

counts=collections.Counter([ntitle(s[3]) for s in spans if ntitle(s[3]) in keys])
dup_before=sum(1 for c in counts.values() if c>1)

seen={}
extras={k:[] for k in keys}
for idx,(hs,he,nxt,title) in enumerate(spans):
    nt=ntitle(title)
    if nt in keys:
        if nt in seen:
            extras[nt].append(t[he:nxt].strip())
        else:
            seen[nt]=idx

res=[]; i=0
for idx,(hs,he,nxt,title) in enumerate(spans):
    nt=ntitle(title)
    # prefixe avant le header
    if i<hs:
        res.append(t[i:hs])
    if nt in keys:
        if seen.get(nt, -1)==idx:
            body=t[he:nxt]
            ex=extras.get(nt,[])
            add=("\n\n"+"\n\n".join([e for e in ex if e])).rstrip("\n") if ex else ""
            seg=t[hs:nxt].rstrip("\n")+(add if add else "")+"\n"
            res.append(seg)
        else:
            pass
    else:
        res.append(t[hs:nxt])
    i=nxt
if i<n:
    res.append(t[i:])
new="".join(res)

counts_after=collections.Counter([ntitle(m.group(2)) for m in pat.finditer(new) if ntitle(m.group(2)) in keys])
dup_after=sum(1 for c in counts_after.values() if c>1)
if new!=t:
    with open(p,"w",encoding="utf-8") as f:
        f.write(new)
print(f"DUP_COUNT_BEFORE={dup_before}")
print(f"DUP_COUNT_AFTER={dup_after}")
' | tee -a "$LOG" >/dev/null

post=$(sha RAG.md)
echo "POST RAG.md ${post}" | tee -a "$LOG" >/dev/null

echo "REPORT=$LOG" | tee -a "$LOG" >/dev/null
