Rails.application.routes.draw do
  # resources :books
   get 'get_books', to: 'books#show'

   post 'create_fruit', to: 'fruit#create'
   get 'get_fruits', to: 'fruit#get_fruits'
   get 'get_status', to: 'artwork#show_order_and_artwork_flow'
   get 'login', to: 'user#main_user_login'
   get 'track_support_enquiries', to: 'chatbot_support#track_support_enquiries'
   get 'order_track', to: 'artwork#show_order_and_artwork_flow'
   get 'cancel_order', to: 'regular_order#create_cancel_orders'
   get 'hold_order', to: 'regular_order#order_on_hold'
   get 'chatbot_option/get_chatbot_options'
   get 'chatbot_option/add_prospect_enquiry'

  # root 'sessions#home'
  # resources :users
  # get 'user/show'
  # get 'user/new'
  # get 'user/create'
  # get 'user/edit'
  # get 'user/update'
  get 'user/destroy'
  # resources :user, only: [:new, :create, :edit, :update, :show, :destroy]

  #sessions routes
  # get '/login', to: 'sessions#login'
  # post 'login', to: 'sessions#create'
  # post 'logout', to: 'sessions#destroy'
  # get '/logout', to: 'sessions#destroy'

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  # root "articles#index"
end
