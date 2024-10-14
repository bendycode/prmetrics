class CreateWeeks < ActiveRecord::Migration[7.1]
  def change
    create_table :weeks do |t|
      t.references :repository, null: false, foreign_key: true
      t.integer :week_number
      t.date :begin_date
      t.date :end_date
      t.integer :num_open_prs
      t.integer :num_prs_started
      t.integer :num_prs_merged
      t.integer :num_prs_initially_reviewed
      t.integer :num_prs_cancelled
      t.decimal :avg_hrs_to_first_review, precision: 10, scale: 2
      t.decimal :avg_hrs_to_merge, precision: 10, scale: 2

      t.timestamps
    end

    add_index :weeks, [:repository_id, :week_number], unique: true
  end
end
