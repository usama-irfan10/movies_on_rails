module MoviesHelper
  SORT_LABELS = {
    "rating_desc" => "Highest rated",
    "rating_asc" => "Lowest rated",
    "title" => "Title"
  }.freeze

  def sort_options
    Movie::SORT_OPTIONS.map { |key| [ SORT_LABELS.fetch(key), key ] }
  end

  def rating_label(movie)
    return "No reviews yet" unless movie.rated?

    "#{number_with_precision(movie.average_stars, precision: 2)} stars from #{pluralize(movie.reviews_count, 'review')}"
  end

  # Sorted in Ruby so the preloaded association is reused (no extra query).
  def cast_list(movie)
    movie.actors.map(&:name).sort.to_sentence
  end

  def locations_list(movie)
    movie.locations.sort_by { |location| [ location.country, location.name ] }.map(&:to_s).to_sentence
  end
end
