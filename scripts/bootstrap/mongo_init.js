/**
 * Usage (local docker):
 *   docker compose up -d mongo
 *   docker compose exec -T mongo mongosh "mongodb://localhost:27017/rbk_labs" /repo/scripts/bootstrap/mongo_init.js
 */

const DB = db.getName();
print(`[mongo_init] connected to db=${DB}`);

function ensureIndex(col, spec, opts) {
  const res = db.getCollection(col).createIndex(spec, opts);
  print(`[mongo_init] ${col}.createIndex(${JSON.stringify(spec)}, ${JSON.stringify(opts)}) -> ${res}`);
}

function ensureCollections(names) {
  const existing = new Set(db.getCollectionNames());
  for (const name of names) {
    if (!existing.has(name)) {
      db.createCollection(name);
      print(`[mongo_init] created collection: ${name}`);
    }
  }
}

ensureCollections([
  "content_items",
  "content_chunks",
  "submissions",
  "autograde_runs",
  "reviews",
  "progress_events",
  "rag_events"
]);

// -------------------- content_items --------------------
ensureIndex("content_items", { content_id: 1 }, { unique: true, name: "uniq_content_id" });
ensureIndex("content_items", { path: 1 }, { unique: true, name: "uniq_path" });
ensureIndex("content_items", { type: 1, track: 1 }, { name: "type_track" });
ensureIndex("content_items", { updated_at: -1 }, { name: "updated_at_desc" });

// -------------------- content_chunks --------------------
ensureIndex("content_chunks", { chunk_id: 1 }, { unique: true, name: "uniq_chunk_id" });
ensureIndex("content_chunks", { content_id: 1, chunk_index: 1 }, { unique: true, name: "uniq_content_chunk_index" });
ensureIndex("content_chunks", { track: 1, week: 1, type: 1 }, { name: "track_week_type" });
ensureIndex("content_chunks", { updated_at: -1 }, { name: "chunks_updated_at_desc" });

// Atlas Search / vector: created via Atlas Admin API later (rag-build-atlas).

// -------------------- submissions --------------------
ensureIndex("submissions", { submission_id: 1 }, { unique: true, name: "uniq_submission_id" });
ensureIndex("submissions", { student_id: 1, lab_id: 1 }, { name: "student_lab" });
ensureIndex("submissions", { status: 1, created_at: -1 }, { name: "status_created_at" });
ensureIndex("submissions", { latest_run_id: 1 }, { name: "latest_run_id" });

// -------------------- autograde_runs --------------------
ensureIndex("autograde_runs", { run_id: 1 }, { unique: true, name: "uniq_run_id" });
ensureIndex("autograde_runs", { submission_id: 1, created_at: -1 }, { name: "sub_created_at" });
ensureIndex("autograde_runs", { status: 1, created_at: -1 }, { name: "run_status_created_at" });

// -------------------- reviews --------------------
ensureIndex("reviews", { review_id: 1 }, { unique: true, name: "uniq_review_id" });
ensureIndex("reviews", { submission_id: 1, created_at: -1 }, { name: "review_submission_created_at" });
ensureIndex("reviews", { mentor_id: 1, created_at: -1 }, { name: "mentor_created_at" });

// -------------------- progress_events --------------------
ensureIndex("progress_events", { student_id: 1, created_at: -1 }, { name: "progress_student_created_at" });
ensureIndex("progress_events", { lab_id: 1, created_at: -1 }, { name: "progress_lab_created_at" });

// -------------------- rag_events --------------------
ensureIndex("rag_events", { created_at: -1 }, { name: "rag_created_at" });
ensureIndex("rag_events", { session_id: 1, created_at: -1 }, { name: "rag_session_created_at" });

print("[mongo_init] done.");
