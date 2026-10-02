class CreatePeople < ActiveRecord::Migration[8.1]
  def change
    create_table :people do |t|
      t.references :company, null: false, foreign_key: true
      t.references :department, foreign_key: true
      t.integer :manager_id
      t.string :name, null: false
      t.string :email, null: false
      t.string :title
      t.string :location
      t.date :start_date
      t.string :roles, array: true, null: false, default: []

      t.timestamps
    end

    add_index :people, :manager_id
  end
end
