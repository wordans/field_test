class <%= migration_class_name %> < ActiveRecord::Migration<%= migration_version %>
  def change
    create_table :field_test_variants do |t|
      t.string :name
      t.float :weight
      t.references :experiments
      t.timestamp :created_at
    end
  end
end
