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

ActiveRecord::Schema[7.1].define(version: 2024_10_14_174252) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "pull_request_users", force: :cascade do |t|
    t.string "role"
    t.bigint "pull_request_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["pull_request_id"], name: "index_pull_request_users_on_pull_request_id"
    t.index ["user_id"], name: "index_pull_request_users_on_user_id"
  end

  create_table "pull_requests", force: :cascade do |t|
    t.integer "number"
    t.string "title"
    t.string "state"
    t.boolean "draft"
    t.datetime "gh_merged_at"
    t.datetime "gh_closed_at"
    t.bigint "repository_id", null: false
    t.datetime "gh_created_at", null: false
    t.datetime "gh_updated_at", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "ready_for_review_at"
    t.bigint "ready_for_review_week_id"
    t.bigint "first_review_week_id"
    t.bigint "merged_week_id"
    t.bigint "closed_week_id"
    t.index ["closed_week_id"], name: "index_pull_requests_on_closed_week_id"
    t.index ["first_review_week_id"], name: "index_pull_requests_on_first_review_week_id"
    t.index ["merged_week_id"], name: "index_pull_requests_on_merged_week_id"
    t.index ["ready_for_review_week_id"], name: "index_pull_requests_on_ready_for_review_week_id"
    t.index ["repository_id"], name: "index_pull_requests_on_repository_id"
  end

  create_table "repositories", force: :cascade do |t|
    t.string "name"
    t.string "url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "last_fetched_at"
  end

  create_table "reviews", force: :cascade do |t|
    t.string "state"
    t.datetime "submitted_at"
    t.bigint "pull_request_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "author_id"
    t.index ["author_id"], name: "index_reviews_on_author_id"
    t.index ["pull_request_id"], name: "index_reviews_on_pull_request_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "username"
    t.string "name"
    t.string "email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "weeks", force: :cascade do |t|
    t.bigint "repository_id", null: false
    t.integer "week_number"
    t.date "begin_date"
    t.date "end_date"
    t.integer "num_open_prs"
    t.integer "num_prs_started"
    t.integer "num_prs_merged"
    t.integer "num_prs_initially_reviewed"
    t.integer "num_prs_cancelled"
    t.decimal "avg_hrs_to_first_review", precision: 10, scale: 2
    t.decimal "avg_hrs_to_merge", precision: 10, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["repository_id", "week_number"], name: "index_weeks_on_repository_id_and_week_number", unique: true
    t.index ["repository_id"], name: "index_weeks_on_repository_id"
  end

  add_foreign_key "pull_request_users", "pull_requests"
  add_foreign_key "pull_request_users", "users"
  add_foreign_key "pull_requests", "repositories"
  add_foreign_key "pull_requests", "weeks", column: "closed_week_id"
  add_foreign_key "pull_requests", "weeks", column: "first_review_week_id"
  add_foreign_key "pull_requests", "weeks", column: "merged_week_id"
  add_foreign_key "pull_requests", "weeks", column: "ready_for_review_week_id"
  add_foreign_key "reviews", "pull_requests"
  add_foreign_key "reviews", "users", column: "author_id"
  add_foreign_key "weeks", "repositories"
end
