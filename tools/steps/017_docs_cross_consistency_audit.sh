#!/usr/bin/env bash
set -euo pipefail

mkdir -p tools/logs
TS="$(date +%Y%m%d_%H%M%S)"
OUT="tools/logs/docs_cross_consistency_${TS}.txt"

python3 - <<'PY' | tee "$OUT" >/dev/null
import re, sys, json, datetime

A='ARCHITECTURE.md'
R='README.md'

with open(A, encoding='utf-8', errors='replace') as f:
    arch = f.read()
with open(R, encoding='utf-8', errors='replace') as f:
    readme = f.read()

H2 = re.compile(r'(?im)^##\s*([A-Za-zÀ-ÖØ-öø-ÿ\s’\'\-]+)\s*$')

# Utilities

def section(text, name):
    m = re.search(rf'(?im)^##\s*{re.escape(name)}\b', text)
    if not m:
        return ''
    s = m.end()
    nxt = re.search(r'(?im)^##\s+[^#].*$', text[s:])
    e = s + (nxt.start() if nxt else len(text[s:]))
    return text[s:e]

norm = lambda s: re.sub(r'\s+', ' ', s.strip().lower())

# Parse components

def parse_components_arch(t):
    body = section(t, 'Composants')
    comps = []
    for ln in body.splitlines():
        m = re.match(r'^-\s*(.+)$', ln.strip())
        if not m:
            continue
        item = m.group(1)
        # normalize
        if item.lower().startswith('api'):
            comps.append('api')
        elif item.lower().startswith('worker'):
            comps.append('worker')
        elif item.lower().startswith('ui'):
            comps.append('ui')
        elif item.lower().startswith('données') or item.lower().startswith('donnees') or 'mongo' in item.lower():
            comps.append('mongo')
    # detect rag mention anywhere
    if re.search(r'(?i)\brag\b', t):
        comps.append('rag (pipeline)')
    # de-dup while preserving order
    seen=set(); out=[]
    for c in comps:
        if c not in seen:
            out.append(c); seen.add(c)
    return out

def parse_components_readme(t):
    heads = []
    for name in ('API','Worker','UI','RAG'):
        if re.search(rf'(?im)^##\s*{name}\b', t):
            heads.append(name.lower())
    return heads

# Parse ports from the Ports section only

def parse_ports(t):
    body = section(t, 'Ports')
    ports = {}
    for ln in body.splitlines():
        m = re.match(r'(?i)^\s*(?:-\s*)?(api|ui)\s*[:=]\s*(\d{2,5})\b', ln.strip())
        if m:
            ports[m.group(1).lower()] = m.group(2)
    return ports

# Parse endpoints from Endpoints section only

def parse_endpoints(t):
    body = section(t, 'Endpoints')
    eps = []
    for ln in body.splitlines():
        m = re.match(r'^\s*(GET|POST)\s+(/\S+)', ln.strip(), re.I)
        if m:
            eps.append((m.group(1).upper() + ' ' + m.group(2)))
    # de-dup
    out=[]; seen=set()
    for e in eps:
        if e not in seen:
            out.append(e); seen.add(e)
    return out

arch_components = parse_components_arch(arch)
readme_components = parse_components_readme(readme)
arch_ports = parse_ports(arch)
readme_ports = parse_ports(readme)
arch_eps = parse_endpoints(arch)
readme_eps = parse_endpoints(readme)

required_ports = {'api':'8000','ui':'3000'}
required_eps = ['GET /health','POST /submissions/upload_zip','POST /rag/query']

findings = []

# Components consistency (compare core: api, worker, ui, rag)
core_arch = set([c.split()[0] for c in arch_components if c.startswith(('api','worker','ui','rag'))])
core_readme = set([c for c in readme_components])
missing_in_arch = sorted(list(core_readme - core_arch))
extra_in_arch = sorted(list(core_arch - core_readme))
if missing_in_arch:
    findings.append('MISMATCH: components missing in ARCHITECTURE vs README -> ' + ', '.join(missing_in_arch))
if extra_in_arch:
    findings.append('MISMATCH: components present in ARCHITECTURE but not in README -> ' + ', '.join(extra_in_arch))

# Ports consistency
if arch_ports != required_ports:
    findings.append(f"MISMATCH: ARCHITECTURE ports {arch_ports} != required {required_ports}")
if readme_ports != required_ports:
    findings.append(f"MISMATCH: README ports {readme_ports} != required {required_ports}")

# Endpoints presence (required subset)
missing_arch_eps = [e for e in required_eps if e not in arch_eps]
missing_readme_eps = [e for e in required_eps if e not in readme_eps]
if missing_arch_eps:
    findings.append('MISMATCH: ARCHITECTURE missing endpoints -> ' + ', '.join(missing_arch_eps))
if missing_readme_eps:
    findings.append('MISMATCH: README missing endpoints -> ' + ', '.join(missing_readme_eps))

# Terminology phantom tech
for label, txt in [('ARCHITECTURE', arch), ('README', readme)]:
    if re.search(r'(?i)\bnext\.js\b', txt):
        findings.append(f'PHANTOM_TECH: Next.js mentioned in {label}')

status = 'OK' if not findings else 'ISSUES'

print('README \u2194 ARCHITECTURE Consistency Audit')
print(f'STATUS: {status}')
print()
print('ARCHITECTURE:')
print('- components: ' + json.dumps(arch_components, ensure_ascii=False))
print('- ports: ' + json.dumps(arch_ports, ensure_ascii=False))
print('- endpoints: ' + json.dumps(arch_eps, ensure_ascii=False))
print()
print('README:')
print('- components: ' + json.dumps(readme_components, ensure_ascii=False))
print('- ports: ' + json.dumps(readme_ports, ensure_ascii=False))
print('- endpoints: ' + json.dumps(readme_eps, ensure_ascii=False))
print()
print('FINDINGS:')
if findings:
    for f in findings:
        print('- ' + f)
else:
    print('- OK: none')
PY

echo "REPORT=$OUT" >> "$OUT"
