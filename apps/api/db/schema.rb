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

ActiveRecord::Schema[8.1].define(version: 2026_10_02_081251) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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

  add_foreign_key "departments", "companies"
  add_foreign_key "departments", "people", column: "head_id"
  add_foreign_key "people", "companies"
  add_foreign_key "people", "departments"
  add_foreign_key "people", "people", column: "manager_id"
end
