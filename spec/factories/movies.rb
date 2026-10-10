FactoryBot.define do
  factory :movie do
    sequence(:title) { |n| "Movie #{n}" }
    description { "A film worth watching." }
    year { 2000 }
    director { "Dana Director" }
  end
end
