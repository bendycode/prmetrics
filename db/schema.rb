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

ActiveRecord::Schema[7.1].define(version: 2025_05_24_150240) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "admins", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "invitation_token"
    t.datetime "invitation_created_at"
    t.datetime "invitation_sent_at"
    t.datetime "invitation_accepted_at"
    t.integer "invitation_limit"
    t.string "invited_by_type"
    t.bigint "invited_by_id"
    t.integer "invitations_count", default: 0
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.index ["email"], name: "index_admins_on_email", unique: true
    t.index ["invitation_token"], name: "index_admins_on_invitation_token", unique: true
    t.index ["invited_by_id"], name: "index_admins_on_invited_by_id"
    t.index ["invited_by_type", "invited_by_id"], name: "index_admins_on_invited_by"
    t.index ["reset_password_token"], name: "index_admins_on_reset_password_token", unique: true
  end

  create_table "github_users", force: :cascade do |t|
    t.string "username", null: false
    t.string "name"
    t.string "avatar_url"
    t.string "github_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["github_id"], name: "index_github_users_on_github_id", unique: true
    t.index ["username"], name: "index_github_users_on_username"
  end

  create_table "pull_request_users", force: :cascade do |t|
    t.string "role"
    t.bigint "pull_request_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["pull_request_id", "role"], name: "idx_pr_users_pr_role"
    t.index ["pull_request_id"], name: "index_pull_request_users_on_pull_request_id"
    t.index ["user_id", "role"], name: "idx_pr_users_user_role"
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
    t.bigint "author_id"
    t.index ["author_id"], name: "index_pull_requests_on_author_id"
    t.index ["closed_week_id"], name: "index_pull_requests_on_closed_week_id"
    t.index ["first_review_week_id"], name: "index_pull_requests_on_first_review_week_id"
    t.index ["gh_closed_at"], name: "idx_pull_requests_gh_closed"
    t.index ["gh_created_at"], name: "idx_pull_requests_gh_created"
    t.index ["gh_merged_at"], name: "idx_pull_requests_gh_merged"
    t.index ["merged_week_id"], name: "index_pull_requests_on_merged_week_id"
    t.index ["ready_for_review_at"], name: "idx_pull_requests_ready_for_review"
    t.index ["ready_for_review_week_id"], name: "index_pull_requests_on_ready_for_review_week_id"
    t.index ["repository_id", "number"], name: "idx_pull_requests_repo_number"
    t.index ["repository_id", "state", "draft"], name: "idx_pull_requests_repo_state_draft"
    t.index ["repository_id"], name: "index_pull_requests_on_repository_id"
  end

  create_table "repositories", force: :cascade do |t|
    t.string "name"
    t.string "url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "last_fetched_at"
    t.string "sync_status"
    t.datetime "sync_started_at"
    t.datetime "sync_completed_at"
    t.text "last_sync_error"
    t.index ["name"], name: "idx_repositories_name"
  end

  create_table "reviews", force: :cascade do |t|
    t.string "state"
    t.datetime "submitted_at"
    t.bigint "pull_request_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "author_id"
    t.index ["author_id"], name: "index_reviews_on_author_id"
    t.index ["pull_request_id", "submitted_at"], name: "idx_reviews_pr_submitted"
    t.index ["pull_request_id"], name: "index_reviews_on_pull_request_id"
    t.index ["submitted_at"], name: "idx_reviews_submitted_at"
  end

  create_table "users", force: :cascade do |t|
    t.string "username"
    t.string "name"
    t.string "email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["username"], name: "idx_users_username"
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
    t.index ["begin_date", "end_date"], name: "idx_weeks_dates"
    t.index ["repository_id", "begin_date", "end_date"], name: "idx_weeks_repo_dates"
    t.index ["repository_id", "week_number"], name: "index_weeks_on_repository_id_and_week_number", unique: true
    t.index ["repository_id"], name: "index_weeks_on_repository_id"
  end

  add_foreign_key "pull_request_users", "pull_requests"
  add_foreign_key "pull_request_users", "users"
  add_foreign_key "pull_requests", "github_users", column: "author_id"
  add_foreign_key "pull_requests", "repositories"
  add_foreign_key "pull_requests", "weeks", column: "closed_week_id"
  add_foreign_key "pull_requests", "weeks", column: "first_review_week_id"
  add_foreign_key "pull_requests", "weeks", column: "merged_week_id"
  add_foreign_key "pull_requests", "weeks", column: "ready_for_review_week_id"
  add_foreign_key "reviews", "pull_requests"
  add_foreign_key "reviews", "users", column: "author_id"
  add_foreign_key "weeks", "repositories"
end
