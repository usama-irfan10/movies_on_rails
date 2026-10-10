Rails.application.routes.draw do
  resource :session, only: %i[new create destroy]
  resources :passwords, param: :token, only: %i[new create edit update]

  root "movies#index"
  resources :movies, only: :index

  namespace :api do
    namespace :v1 do
      resources :movies, only: %i[index show] do
        resources :reviews, only: :index
      end
    end

    # Any other /api/... path: JSON 404 (keep this last in the namespace).
    match "*path", to: "v1/fallback#show", via: :all, format: false
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
