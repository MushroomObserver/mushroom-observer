MushroomObserver::Application.routes.draw do
  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  # root 'welcome#index'

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end

  get "publications/:id/destroy" => "publications#destroy"
  resources :publications

  # Default page is /observer/index.
  root "observer#index"

  # Route /123 to /observer/show_observation/123.
  get ":id" => "observer#show_observation", constraints: { id: /\d+/ }

  # Short-hand notation for AJAX methods.
  get "ajax/:action/:type/:id" => "ajax", constraints: { id: /\S.*/ }

  # Default action for any controller is "index".
  get ":controller" => "controller#index"

  # Standard routes.
  get ":controller/:action"
  match ":controller(/:action(/:id))", constraints: { id: /\d+/ },
    via: [:get, :post]

  # Accept non-numeric ids for the lookup_xxx actions.
  get ":controller/:action/:id", action: /lookup_\w+/
end
