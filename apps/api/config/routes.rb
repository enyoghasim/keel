Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  mount ActionCable.server => "/cable"

  namespace :api do
    resources :companies, only: [ :create, :show ] do
      resource :session, only: [ :create, :show, :destroy ]
      resources :people, only: [ :index, :show ]
      resources :departments, only: [ :index, :show ]
      resources :policies, only: [ :index, :show ] do
        resources :rules, only: [ :index, :show ]
        post :test, on: :member
      end
      resources :requests, only: [ :index, :create, :show ]
      resources :workflows, only: [ :index, :show ] do
        post :test_run, on: :member
      end
      resources :change_proposals, only: [ :index, :create, :show ] do
        post :approve, on: :member
        post :reject, on: :member
      end
      resources :insights, only: [ :index, :create, :show ]
      resources :eval_runs, only: [ :index, :create, :show ]
      resources :agent_runs, only: [ :index, :create, :show ]
    end

    resources :step_runs, only: [] do
      post :act, on: :member
    end
  end
end
