Rails.application.routes.draw do
  root to: 'pages#show', id: 'home'

  get '/blog', to: 'posts#index'
  get '/blog/:id', to: 'posts#show'

  get '/*id' => 'pages#show', as: :page, format: false
end
