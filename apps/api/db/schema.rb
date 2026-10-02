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

ActiveRecord::Schema[8.1].define(version: 2026_10_02_092135) do
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
  end

  create_table "departments", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.string "name", null: false
    t.integer "head_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_departments_on_company_id"
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
    t.index ["company_id"], name: "index_people_on_company_id"
    t.index ["department_id"], name: "index_people_on_department_id"
    t.index ["manager_id"], name: "index_people_on_manager_id"
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
  add_foreign_key "chunks", "source_documents"
  add_foreign_key "departments", "companies"
  add_foreign_key "departments", "people", column: "head_id"
  add_foreign_key "import_issues", "companies"
  add_foreign_key "people", "companies"
  add_foreign_key "people", "departments"
  add_foreign_key "people", "people", column: "manager_id"
  add_foreign_key "requests", "companies"
  add_foreign_key "requests", "people", column: "requester_id"
  add_foreign_key "source_documents", "companies"
  add_foreign_key "step_runs", "people", column: "resolved_person_id"
  add_foreign_key "step_runs", "workflow_runs"
  add_foreign_key "workflow_runs", "requests"
  add_foreign_key "workflow_runs", "workflows"
  add_foreign_key "workflows", "companies"
end
