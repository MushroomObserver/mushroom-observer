# Rails.application.routes.draw do
MushroomObserver::Application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
 get "publications/:id/destroy" => "publications#destroy"
  resources :publications

  # Default page
  root "observer#list_rss_logs"

  # Route /123 to /observer/show_observation/123.
  get ":id" => "observer#show_observation", constraints: { id: /\d+/ }

  # Short-hand notation for AJAX methods.
  get "ajax/:action/:type/:id" => "ajax", constraints: { id: /\S.*/ }

  # Default action for any controller is "index".
  get ":controller" => "controller#index"

  # Standard routes.
  # BEWARE: This makes all non-private methods available as actions
  get ":controller/:action"
  match ":controller(/:action(/:id))", constraints: { id: /\d+/ },
                                       via: [:get, :post]

  # Accept non-numeric ids for the lookup_xxx actions.
  get ":controller/:action/:id", action: /lookup_\w+/
end
