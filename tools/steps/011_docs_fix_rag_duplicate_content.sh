#!/usr/bin/env bash
set -euo pipefail

mkdir -p tools/logs
TS="$(date +%Y%m%d_%H%M%S)"
LOG="tools/logs/docs_fix_rag_content_${TS}.txt"

sha() { sha256sum "$1" | awk '{print $1}'; }

PRE=$(sha RAG.md)
echo "PRE RAG.md ${PRE}" | tee "$LOG" >/dev/null

python3 -c 'import re,sys
p="RAG.md"
with open(p,encoding="utf-8") as f:
    t=f.read()

# Identify heading lines
lines=t.replace("\r","").split("\n")
head_idxs=[i for i,l in enumerate(lines) if re.match(r"^#{1,6}\s+", l)]
# Add sentinel end
head_idxs.append(len(lines))

removed=0
out_lines=[]
prev_end=0
for h in range(len(head_idxs)-1):
    start=head_idxs[h]
    end=head_idxs[h+1]
    # emit any preface before first heading unchanged
    if h==0 and start>0:
        out_lines.extend(lines[0:start])
    # heading line
    out_lines.append(lines[start])
    body=lines[start+1:end]
    # split body into paragraphs by empty lines
    paras=[]; cur=[]
    for ln in body:
        if ln.strip()=="":
            if cur is not None:
                paras.append("\n".join(cur))
                cur=[]
            paras.append("")  # marker for blank line
        else:
            cur.append(ln)
    if cur:
        paras.append("\n".join(cur))
    # dedupe consecutive non-empty paragraphs
    def norm(s):
        ss=[x.rstrip() for x in s.split("\n")]
        while ss and ss[0]=="": ss.pop(0)
        while ss and ss[-1]=="": ss.pop()
        return "\n".join(ss)
    new_body=[]
    last_para_norm=None
    i=0
    while i<len(paras):
        blk=paras[i]
        if blk=="":
            # preserve a single blank line
            if not new_body or new_body[-1] != "":
                new_body.append("")
            i+=1
            continue
        nb=norm(blk)
        if last_para_norm is not None and nb==last_para_norm:
            removed+=1
            # skip duplicate paragraph
            i+=1
            # do not add extra blank line here
            continue
        new_body.append(blk)
        last_para_norm=nb
        i+=1
    # emit body back
    # ensure no trailing multiple blanks
    while new_body and new_body[-1]=="":
        new_body.pop()
    # write body with original blank line separators (single empty string -> blank line)
    for j,blk in enumerate(new_body):
        if blk=="":
            out_lines.append("")
        else:
            out_lines.extend(blk.split("\n"))

# Append any tail after last heading (unlikely)
if head_idxs[0]==len(lines):
    # no headings; dedupe globally by paragraphs
    text=t
else:
    text="\n".join(out_lines)

if text!=t:
    with open(p, "w", encoding="utf-8") as f:
        f.write(text)
print(f"REMOVED_BLOCKS={removed}")
' | tee -a "$LOG" >/dev/null

POST=$(sha RAG.md)
echo "POST RAG.md ${POST}" | tee -a "$LOG" >/dev/null

echo "REPORT=$LOG" | tee -a "$LOG" >/dev/null
