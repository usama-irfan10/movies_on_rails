class ReviewSerializer < ActiveModel::Serializer
  attributes :id, :user_name, :stars, :comment, :created_at
end
