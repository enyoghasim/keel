# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_02_182000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "agent_runs", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "person_id", null: false
    t.text "message", null: false
    t.string "status", default: "pending", null: false
    t.text "final_text"
    t.integer "total_tokens", default: 0, null: false
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "conversation_id", default: -> { "gen_random_uuid()" }, null: false
    t.string "feedback"
    t.string "feedback_reason"
    t.text "feedback_note"
    t.decimal "cost_usd", precision: 10, scale: 6
    t.index ["company_id"], name: "index_agent_runs_on_company_id"
    t.index ["person_id", "conversation_id"], name: "index_agent_runs_on_person_id_and_conversation_id"
    t.index ["person_id"], name: "index_agent_runs_on_person_id"
  end

  create_table "agent_steps", force: :cascade do |t|
    t.bigint "agent_run_id", null: false
    t.integer "position", null: false
    t.string "kind", null: false
    t.string "tool_name"
    t.jsonb "input"
    t.jsonb "output"
    t.integer "latency_ms"
    t.integer "tokens"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["agent_run_id", "position"], name: "index_agent_steps_on_agent_run_id_and_position", unique: true
    t.index ["agent_run_id"], name: "index_agent_steps_on_agent_run_id"
  end

  create_table "change_proposals", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.string "kind", null: false
    t.string "title", null: false
    t.jsonb "diff", default: [], null: false
    t.jsonb "impact", default: {}, null: false
    t.string "proposed_by", default: "user", null: false
    t.string "status", default: "pending", null: false
    t.bigint "decided_by_id"
    t.datetime "decided_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "agent_run_id"
    t.text "explanation"
    t.index ["agent_run_id"], name: "index_change_proposals_on_agent_run_id"
    t.index ["company_id"], name: "index_change_proposals_on_company_id"
    t.index ["decided_by_id"], name: "index_change_proposals_on_decided_by_id"
  end

  create_table "chunks", force: :cascade do |t|
    t.bigint "source_document_id", null: false
    t.integer "page", null: false
    t.integer "position", null: false
    t.text "text", null: false
    t.vector "embedding", limit: 1536
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["source_document_id"], name: "index_chunks_on_source_document_id"
  end

  create_table "companies", force: :cascade do |t|
    t.string "name", null: false
    t.string "locale", default: "en", null: false
    t.jsonb "settings", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "assemble_completed_stages", default: [], null: false, array: true
  end

  create_table "departments", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.string "name", null: false
    t.integer "head_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_departments_on_company_id"
  end

  create_table "eval_cases", force: :cascade do |t|
    t.string "suite", null: false
    t.string "key", null: false
    t.jsonb "input", default: {}, null: false
    t.jsonb "expected", default: {}, null: false
    t.string "source", default: "manual", null: false
    t.string "status", default: "active", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["suite", "key"], name: "index_eval_cases_on_suite_and_key", unique: true
  end

  create_table "eval_results", force: :cascade do |t|
    t.bigint "eval_run_id", null: false
    t.bigint "eval_case_id", null: false
    t.boolean "passed", default: false, null: false
    t.jsonb "actual"
    t.jsonb "diff", default: [], null: false
    t.integer "latency_ms"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "score", precision: 5, scale: 4
    t.jsonb "metrics", default: {}, null: false
    t.index ["eval_case_id"], name: "index_eval_results_on_eval_case_id"
    t.index ["eval_run_id", "eval_case_id"], name: "index_eval_results_on_eval_run_id_and_eval_case_id", unique: true
    t.index ["eval_run_id"], name: "index_eval_results_on_eval_run_id"
  end

  create_table "eval_runs", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "person_id"
    t.string "suite", null: false
    t.string "status", default: "pending", null: false
    t.string "model"
    t.decimal "accuracy", precision: 5, scale: 4
    t.integer "cases_count", default: 0, null: false
    t.integer "passed_count", default: 0, null: false
    t.datetime "started_at"
    t.datetime "finished_at"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "prompt_version_id"
    t.integer "stability_samples", default: 0, null: false
    t.decimal "stability", precision: 5, scale: 4
    t.decimal "judge_score", precision: 4, scale: 2
    t.decimal "cost_usd", precision: 10, scale: 6
    t.decimal "judge_agreement", precision: 5, scale: 4
    t.index ["company_id"], name: "index_eval_runs_on_company_id"
    t.index ["person_id"], name: "index_eval_runs_on_person_id"
    t.index ["prompt_version_id"], name: "index_eval_runs_on_prompt_version_id"
  end

  create_table "import_issues", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.integer "row_number", null: false
    t.string "field", null: false
    t.string "raw_value"
    t.string "message", null: false
    t.boolean "resolved", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_import_issues_on_company_id"
  end

  create_table "insight_queries", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "person_id", null: false
    t.text "question", null: false
    t.string "status", default: "pending", null: false
    t.jsonb "query"
    t.text "clarification"
    t.jsonb "result"
    t.text "error_message"
    t.string "model"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_insight_queries_on_company_id"
    t.index ["person_id"], name: "index_insight_queries_on_person_id"
  end

  create_table "mcp_calls", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "person_id", null: false
    t.bigint "personal_access_token_id"
    t.string "tool_name", null: false
    t.jsonb "input", default: {}, null: false
    t.jsonb "output"
    t.boolean "is_error", default: false, null: false
    t.integer "latency_ms"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_mcp_calls_on_company_id"
    t.index ["person_id"], name: "index_mcp_calls_on_person_id"
    t.index ["personal_access_token_id"], name: "index_mcp_calls_on_personal_access_token_id"
  end

  create_table "people", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "department_id"
    t.integer "manager_id"
    t.string "name", null: false
    t.string "email", null: false
    t.string "title"
    t.string "location"
    t.date "start_date"
    t.string "roles", default: [], null: false, array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "password_digest"
    t.index ["company_id"], name: "index_people_on_company_id"
    t.index ["department_id"], name: "index_people_on_department_id"
    t.index ["manager_id"], name: "index_people_on_manager_id"
  end

  create_table "personal_access_tokens", force: :cascade do |t|
    t.bigint "person_id", null: false
    t.string "name", null: false
    t.string "token_digest", null: false
    t.datetime "last_used_at"
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["person_id"], name: "index_personal_access_tokens_on_person_id"
    t.index ["token_digest"], name: "index_personal_access_tokens_on_token_digest", unique: true
  end

  create_table "policies", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.string "title", null: false
    t.string "category", null: false
    t.string "status", default: "draft", null: false
    t.integer "version", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_policies_on_company_id"
  end

  create_table "prompt_versions", force: :cascade do |t|
    t.string "key", null: false
    t.integer "version", null: false
    t.text "template", null: false
    t.string "model"
    t.boolean "active", default: false, null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key", "version"], name: "index_prompt_versions_on_key_and_version", unique: true
    t.index ["key"], name: "index_prompt_versions_one_active_per_key", unique: true, where: "active"
  end

  create_table "requests", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "requester_id", null: false
    t.string "kind", null: false
    t.jsonb "payload", default: {}, null: false
    t.string "decision"
    t.string "matched_rule_ids", default: [], null: false, array: true
    t.integer "policy_version"
    t.string "status", default: "pending", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_requests_on_company_id"
    t.index ["requester_id"], name: "index_requests_on_requester_id"
  end

  create_table "rules", force: :cascade do |t|
    t.bigint "policy_id", null: false
    t.bigint "source_chunk_id", null: false
    t.string "key", null: false
    t.jsonb "conditions", default: {}, null: false
    t.jsonb "actions", default: {}, null: false
    t.integer "priority", default: 0, null: false
    t.text "source_quote", null: false
    t.jsonb "ambiguities", default: [], null: false
    t.string "status", default: "extracted", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["policy_id"], name: "index_rules_on_policy_id"
    t.index ["source_chunk_id"], name: "index_rules_on_source_chunk_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "person_id", null: false
    t.string "token_digest", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["person_id"], name: "index_sessions_on_person_id"
    t.index ["token_digest"], name: "index_sessions_on_token_digest", unique: true
  end

  create_table "source_documents", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.string "filename", null: false
    t.string "kind", null: false
    t.integer "page_count"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_source_documents_on_company_id"
  end

  create_table "step_runs", force: :cascade do |t|
    t.bigint "workflow_run_id", null: false
    t.string "step_key", null: false
    t.string "reference"
    t.bigint "resolved_person_id"
    t.string "status", default: "pending", null: false
    t.datetime "acted_at"
    t.boolean "overridden", default: false, null: false
    t.text "override_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["resolved_person_id"], name: "index_step_runs_on_resolved_person_id"
    t.index ["workflow_run_id"], name: "index_step_runs_on_workflow_run_id"
  end

  create_table "workflow_edits", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "person_id", null: false
    t.bigint "workflow_id", null: false
    t.bigint "change_proposal_id"
    t.text "instruction", null: false
    t.string "status", default: "pending", null: false
    t.text "error_message"
    t.string "model"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["change_proposal_id"], name: "index_workflow_edits_on_change_proposal_id"
    t.index ["company_id"], name: "index_workflow_edits_on_company_id"
    t.index ["person_id"], name: "index_workflow_edits_on_person_id"
    t.index ["workflow_id"], name: "index_workflow_edits_on_workflow_id"
  end

  create_table "workflow_runs", force: :cascade do |t|
    t.bigint "request_id", null: false
    t.bigint "workflow_id"
    t.string "current_step"
    t.string "status", default: "in_progress", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["request_id"], name: "index_workflow_runs_on_request_id", unique: true
    t.index ["workflow_id"], name: "index_workflow_runs_on_workflow_id"
  end

  create_table "workflows", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.string "name", null: false
    t.jsonb "trigger", default: {}, null: false
    t.jsonb "steps", default: [], null: false
    t.integer "version", default: 1, null: false
    t.string "status", default: "draft", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_workflows_on_company_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "agent_runs", "companies"
  add_foreign_key "agent_runs", "people"
  add_foreign_key "agent_steps", "agent_runs"
  add_foreign_key "change_proposals", "agent_runs"
  add_foreign_key "change_proposals", "companies"
  add_foreign_key "change_proposals", "people", column: "decided_by_id"
  add_foreign_key "chunks", "source_documents"
  add_foreign_key "departments", "companies"
  add_foreign_key "departments", "people", column: "head_id"
  add_foreign_key "eval_results", "eval_cases"
  add_foreign_key "eval_results", "eval_runs"
  add_foreign_key "eval_runs", "companies"
  add_foreign_key "eval_runs", "people"
  add_foreign_key "eval_runs", "prompt_versions"
  add_foreign_key "import_issues", "companies"
  add_foreign_key "insight_queries", "companies"
  add_foreign_key "insight_queries", "people"
  add_foreign_key "mcp_calls", "companies"
  add_foreign_key "mcp_calls", "people"
  add_foreign_key "mcp_calls", "personal_access_tokens"
  add_foreign_key "people", "companies"
  add_foreign_key "people", "departments"
  add_foreign_key "people", "people", column: "manager_id"
  add_foreign_key "personal_access_tokens", "people"
  add_foreign_key "policies", "companies"
  add_foreign_key "requests", "companies"
  add_foreign_key "requests", "people", column: "requester_id"
  add_foreign_key "rules", "chunks", column: "source_chunk_id"
  add_foreign_key "rules", "policies"
  add_foreign_key "sessions", "people"
  add_foreign_key "source_documents", "companies"
  add_foreign_key "step_runs", "people", column: "resolved_person_id"
  add_foreign_key "step_runs", "workflow_runs"
  add_foreign_key "workflow_edits", "change_proposals"
  add_foreign_key "workflow_edits", "companies"
  add_foreign_key "workflow_edits", "people"
  add_foreign_key "workflow_edits", "workflows"
  add_foreign_key "workflow_runs", "requests"
  add_foreign_key "workflow_runs", "workflows"
  add_foreign_key "workflows", "companies"
end
