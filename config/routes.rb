Rails.application.routes.draw do
  root to: 'pages#show', id: 'home'

  get '/*id' => 'pages#show', as: :page, format: false
end
