class <%= migration_class_name %> < ActiveRecord::Migration<%= migration_version %>
  def change
    create_table :field_test_experiments do |t|
      t.string :name
      t.text :description
      t.float :weight
      t.string :winner
      t.timestamp :started_at
      t.timestamp :ended_at
      t.timestamp :created_at
    end
  end
end
