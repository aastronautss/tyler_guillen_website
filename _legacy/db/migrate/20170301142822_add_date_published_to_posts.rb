class AddDatePublishedToPosts < ActiveRecord::Migration[5.0]
  def change
    add_column :posts, :date_published, :timestamp
  end
end
