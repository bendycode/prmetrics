class AddApiTokenToTrackers < ActiveRecord::Migration[7.2]
  def change
    add_column :trackers, :api_token, :text
  end
end
