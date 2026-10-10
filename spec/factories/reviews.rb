FactoryBot.define do
  factory :review do
    movie
    sequence(:user_name) { |n| "Reviewer #{n}" }
    stars { 4 }
    comment { "Really good!" }
  end
end
