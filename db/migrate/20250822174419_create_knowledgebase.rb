class CreateKnowledgebase < ActiveRecord::Migration[7.1]
  def change
    create_table :knowledgebases do |t|
      t.string :short
      t.integer :position
      t.boolean :frontpage
      t.string :lang
      t.string :title
      t.string :icon
      t.text :intro
      t.string :link
      t.string :description

      t.timestamps
    end
  end
end