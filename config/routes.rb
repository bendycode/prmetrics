Rails.application.routes.draw do
  root 'repositories#index'

  resources :repositories, only: [:index, :show] do
    resources :pull_requests, only: [:index]
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
