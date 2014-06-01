MushroomObserver::Application.routes.draw do |map|
  map.resources :publications

  # The priority is based upon order of creation: first created -> highest priority.

  # Default page is /observer/index.
  map.connect '', :controller => 'observer', :action => 'index'
  # was: map.connect '', :controller => 'observer' (??!)

  # Default action for any controller is 'index'.
  map.connect ':controller', :action => 'index'
  # was: map.connect 'pivotal', :controller => 'pivotal', :action => 'index'

  # Route /123 to /observer/show_observation/123.
  map.connect ':id', :controller => 'observer', :action => 'show_observation', :id => /\d+/
  map.connect 'obs', :controller => 'observer', :action => 'show_observation'
  map.connect 'obs/:id', :controller => 'observer', :action => 'show_observation', :id => /\d+/
  # was: map.connect ':id', :controller => 'observer', :action => 'show_obs'
  # was: map.connect 'obs/:id', :controller => 'observer', :action => 'show_observation'

  # Short-hand notation for AJAX methods.
  map.connect 'ajax/:action/:type/:id', :controller => 'ajax', :id => /\S.*/

  # Standard routes.
  map.connect ':controller/:action'
  map.connect ':controller/:action/:id', :id => /\d+/
  # was: map.connect ':controller/:action/:id', :controller => 'observer' (??!)

  # Accept non-numeric ids for the lookup_xxx actions.
  map.connect ':controller/:action/:id', :action => /lookup_\w+/
  # was: map.connect 'observer/:action/:id', :controller => 'observer', :action => /lookup_\w+/, :id => /.*/


  # The priority is based upon order of creation:
  # first created -> highest priority.

  # Sample of regular route:
  #   match 'products/:id' => 'catalog#view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   match 'products/:id/purchase' => 'catalog#purchase', :as => :purchase
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Sample resource route with options:
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

  # Sample resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Sample resource route with more complex sub-resources
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', :on => :collection
  #     end
  #   end

  # Sample resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end

  # You can have the root of your site routed with "root"
  # just remember to delete public/index.html.
  # root :to => "welcome#index"

  # See how all your routes lay out with "rake routes"

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  # match ':controller(/:action(/:id(.:format)))'
end
