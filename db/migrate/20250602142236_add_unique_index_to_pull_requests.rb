class AddUniqueIndexToPullRequests < ActiveRecord::Migration[7.1]
  def change
    # Remove duplicates before adding the unique constraint
    execute <<-SQL
      DELETE FROM pull_requests
      WHERE id NOT IN (
        SELECT MAX(id)
        FROM pull_requests
        GROUP BY repository_id, number
      )
    SQL
    
    # Add unique constraint to prevent future duplicates
    add_index :pull_requests, [:repository_id, :number], unique: true, name: 'index_pull_requests_on_repository_id_and_number_unique'
    
    # Remove the old non-unique index if it exists
    remove_index :pull_requests, [:repository_id, :number], if_exists: true, name: 'idx_pull_requests_repo_number'
  end
end
