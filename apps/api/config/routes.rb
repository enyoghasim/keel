Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  mount ActionCable.server => "/cable"

  namespace :api do
    resources :companies, only: [ :create, :show ] do
      resources :people, only: [ :index, :show ]
      resources :departments, only: [ :index, :show ]
      resources :policies, only: [ :index, :show ] do
        resources :rules, only: [ :index, :show ]
        post :test, on: :member
      end
    end
  end
end
