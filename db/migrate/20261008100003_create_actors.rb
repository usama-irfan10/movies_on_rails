class CreateActors < ActiveRecord::Migration[8.0]
  def change
    create_table :actors do |t|
      t.string :name, null: false

      t.timestamps
    end

    add_index :actors, "lower(name)", unique: true, name: "index_actors_on_lower_name"
    # Trigram index: makes partial, case-insensitive search (ILIKE '%term%') index-backed.
    add_index :actors, :name, using: :gin, opclass: :gin_trgm_ops, name: "index_actors_on_name_trgm"
  end
end
