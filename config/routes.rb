require 'sidekiq/web'

Rails.application.routes.draw do
  devise_for :users

  # Secure Sidekiq Web UI with Devise authentication
  authenticate :user do
    mount Sidekiq::Web => '/sidekiq'
  end

  root 'dashboard#index'
  get 'dashboard', to: 'dashboard#index'
  get 'health', to: 'health#show'

  resource :account, only: %i[edit update]
  resources :users, only: %i[index new create destroy]

  resources :repositories, only: %i[index show new create destroy] do
    member do
      post :sync
    end
    resources :pull_requests, only: [:index]
    resources :weeks, only: %i[index show] do
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
  resources :contributors, only: %i[index show]

  get "up" => "rails/health#show", as: :rails_health_check
end
