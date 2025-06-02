class AddUniqueIndexToReviews < ActiveRecord::Migration[7.1]
  def change
    # Remove duplicates before adding the unique constraint
    # Keep the first review for each unique combination
    execute <<-SQL
      DELETE FROM reviews
      WHERE id NOT IN (
        SELECT MIN(id)
        FROM reviews
        GROUP BY pull_request_id, author_id, submitted_at, state
      )
    SQL
    
    # Add unique constraint to prevent future duplicates
    add_index :reviews, [:pull_request_id, :author_id, :submitted_at, :state], 
              unique: true, 
              name: 'index_reviews_uniqueness'
    
    # Add model-level validation comment
    reversible do |dir|
      dir.up do
        execute <<-SQL
          COMMENT ON INDEX index_reviews_uniqueness IS 
          'Prevents duplicate reviews from same author at same time with same state';
        SQL
      end
    end
  end
end
