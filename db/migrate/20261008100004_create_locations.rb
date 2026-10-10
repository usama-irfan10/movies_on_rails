class CreateLocations < ActiveRecord::Migration[8.0]
  def change
    create_table :locations do |t|
      t.string :name, null: false
      t.string :country, null: false

      t.timestamps
    end

    add_index :locations, "lower(name), country", unique: true, name: "index_locations_on_lower_name_and_country"
  end
end
