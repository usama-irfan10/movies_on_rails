Rails.application.routes.draw do
  # Development only: lists emails sent by the app (see config/initializers/action_mailer.rb).
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?

  # API documentation (Swagger UI); the rswag gems are not installed in production.
  unless Rails.env.production?
    mount Rswag::Ui::Engine => "/api-docs"
    mount Rswag::Api::Engine => "/api-docs"
  end

  resource :session, only: %i[new create destroy]
  resources :passwords, param: :token, only: %i[new create edit update]

  root "movies#index"
  resources :movies, only: :index

  namespace :api do
    namespace :v1 do
      post "tokens", to: "tokens#create"
      delete "tokens", to: "tokens#destroy"
      resources :movies, only: %i[index show] do
        resources :reviews, only: :index
      end
    end

    # Any other /api/... path: JSON 404 (keep this last in the namespace).
    match "*path", to: "v1/fallback#show", via: :all, format: false
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
