# Trigram indexes make partial, case-insensitive name search (ILIKE '%term%') index-backed.
class EnablePgTrgm < ActiveRecord::Migration[8.0]
  def change
    enable_extension "pg_trgm"
  end
end
