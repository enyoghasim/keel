Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  mount ActionCable.server => "/cable"
  # Keel's MCP server (SPEC.md section 13), authenticated by personal access token.
  mount KeelMcp::Endpoint.new => "/mcp"

  namespace :api do
    # Which company this deployment serves — public, so a fresh browser can find it.
    resource :workspace, only: :show
    resources :companies, only: [ :create, :show ] do
      resource :session, only: [ :create, :show, :update, :destroy ]
      resources :assemble_events, only: :index
      resource :demo_reset, only: :create
      resources :people, only: [ :index, :show ]
      resources :departments, only: [ :index, :show ]
      resources :policies, only: [ :index, :show ] do
        resources :rules, only: [ :index, :show ]
        resources :rule_resolutions, only: [ :create, :show ]
        post :test, on: :member
        get :conflicts, on: :member
        post :conflict_fixes, on: :member
        post :publish, on: :member
      end
      resources :requests, only: [ :index, :create, :show ]
      resources :workflows, only: [ :index, :show ] do
        post :test_run, on: :member
        resources :edits, controller: "workflow_edits", only: [ :create, :show ]
      end
      resources :change_proposals, only: [ :index, :create, :show ] do
        post :approve, on: :member
        post :reject, on: :member
        get :trace, on: :member
      end
      resources :personal_access_tokens, only: [ :index, :create, :destroy ]
      resources :mcp_calls, only: [ :index ]
      resources :insights, only: [ :index, :create, :show ]
      resources :eval_runs, only: [ :index, :create, :show ]
      resources :eval_cases, only: [ :index, :update ]
      resources :prompt_versions, only: [ :index, :show ] do
        post :promote, on: :member
      end
      resources :agent_runs, only: [ :index, :create, :show ] do
        post :feedback, on: :member
      end
    end

    resources :step_runs, only: [] do
      post :act, on: :member
    end
  end
end
