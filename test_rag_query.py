from api.app.routers.rag import rag_query, RagQuery

payload = RagQuery(query="Comment securiser un PDA ?", context_lab_id=None)
res = rag_query(payload)

print("system_prompt:\n", res.system_prompt[:800])
print("\nchunks:")
for c in res.chunks:
    print(f"- {c.source} ({c.score}): {c.id}")
