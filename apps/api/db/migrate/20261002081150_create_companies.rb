class CreateCompanies < ActiveRecord::Migration[8.1]
  def change
    create_table :companies do |t|
      t.string :name, null: false
      t.string :locale, null: false, default: "en"
      t.jsonb :settings, null: false, default: {}

      t.timestamps
    end
  end
end
