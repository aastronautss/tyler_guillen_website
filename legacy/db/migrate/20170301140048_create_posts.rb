class CreatePosts < ActiveRecord::Migration[5.0]
  def change
    create_table :posts do |t|
      t.string :title
      t.text :blurb
      t.text :content
      t.integer :category_id

      t.timestamps
    end

    add_index :posts, :category_id
  end
end
