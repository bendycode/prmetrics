require 'sidekiq/web'

Rails.application.routes.draw do
  devise_for :admins
  
  # Secure Sidekiq Web UI with Devise authentication
  authenticate :admin do
    mount Sidekiq::Web => '/sidekiq'
  end
  
  root 'repositories#index'
  
  resource :account, only: [:edit, :update]
  resources :admins, only: [:index, :new, :create, :destroy]

  resources :repositories, only: [:index, :show] do
    member do
      post :sync
    end
    resources :pull_requests, only: [:index]
  end

  resources :repositories do
    resources :weeks, only: [:index, :show] do
      member do
        get 'pr_list'
      end
    end
  end

  resources :pull_requests, only: [:show] do
    resources :reviews, only: [:index]
    resources :pull_request_users, only: [:index]
  end

  resources :reviews, only: [:show]
  resources :pull_request_users, only: [:show]
  resources :users, only: [:index, :show]

  get "up" => "rails/health#show", as: :rails_health_check
end
