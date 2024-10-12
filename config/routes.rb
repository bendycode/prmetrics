Rails.application.routes.draw do
  get 'users/index'
  get 'users/show'
  get 'pull_request_users/index'
  get 'pull_request_users/show'
  get 'reviews/index'
  get 'reviews/show'
  get 'pull_requests/index'
  get 'pull_requests/show'
  get 'repositories/index'
  get 'repositories/show'
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
end
