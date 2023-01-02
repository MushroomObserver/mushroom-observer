# frozen_string_literal: true

# Nested hash of permissible controllers and actions. Each entry as follows,
# with missing element meaning use default:
#
# controller: {    # hash of controller actions
#   action_name: {    # hash of attributes for this action
#     methods:  (array),  # allowed HTML methods, as symbols
#                         # methods key omitted => default: [:get, :post]
#     segments: (string), # expected segments, with leading slash(es)
#                         # segments key omitted => default: "/:id"
#                         # blank string means no segments allowed
#     id_constraint: (string|regexp)  # any constraint on id, default: /d+/
#   }
# }
#
# Note that the hash of attributes is not yet actually used.
#
ACTIONS = {
  ajax: {
    api_key: {},
    auto_complete: {},
    create_image_object: {},
    exif: {},
    export: {},
    external_link: {},
    geocode: {},
    image: {},
    location_primer: {},
    name_primer: {},
    multi_image_template: {},
    old_translation: {},
    pivotal: {},
    test: {},
    visual_group_status: {},
    vote: {}
  },
  api: {
    api_keys: {},
    collection_numbers: {},
    comments: {},
    external_links: {},
    external_sites: {},
    herbaria: {},
    herbarium_records: {},
    images: {},
    locations: {},
    names: {},
    observations: {},
    projects: {},
    sequences: {},
    species_lists: {},
    users: {}
  },
  api2: {
    api_keys: {},
    collection_numbers: {},
    comments: {},
    external_links: {},
    external_sites: {},
    herbaria: {},
    herbarium_records: {},
    images: {},
    locations: {},
    names: {},
    observations: {},
    projects: {},
    sequences: {},
    species_lists: {},
    users: {}
  },
  image: {
    add_image: {},
    advanced_search: {},
    bulk_filename_purge: {},
    bulk_vote_anonymity_updater: {},
    cast_vote: {},
    destroy_image: {},
    edit_image: {},
    image_search: {},
    images_by_user: {},
    images_for_project: {},
    index_image: {},
    license_updater: {},
    list_images: {},
    next_image: {},
    prev_image: {},
    remove_images: {},
    remove_images_for_glossary_term: {},
    reuse_image: {},
    reuse_image_for_glossary_term: {},
    # show_image: {},
    show_original: {},
    transform_image: {}
  },
  location: {
    add_to_location: {},
    adjust_permissions: {},
    advanced_search: {},
    create_location: {},
    create_location_description: {},
    destroy_location: {},
    destroy_location_description: {},
    edit_location: {},
    edit_location_description: {},
    help: {},
    index_location: {},
    index_location_description: {},
    list_by_country: {},
    list_countries: {},
    list_location_descriptions: {},
    list_locations: {},
    list_merge_options: {},
    location_descriptions_by_author: {},
    location_descriptions_by_editor: {},
    location_search: {},
    locations_by_editor: {},
    locations_by_user: {},
    make_description_default: {},
    map_locations: {},
    merge_descriptions: {},
    next_location: {},
    next_location_description: {},
    prev_location: {},
    prev_location_description: {},
    publish_description: {},
    reverse_name_order: {},
    # show_location: {},
    show_location_description: {},
    show_past_location: {},
    show_past_location_description: {}
  },
  name: {
    adjust_permissions: {},
    advanced_search: {},
    approve_name: {},
    approve_tracker: {},
    authored_names: {},
    bulk_name_edit: {},
    change_synonyms: {},
    create_name: {},
    create_name_description: {},
    deprecate_name: {},
    destroy_name_description: {},
    edit_classification: {},
    edit_lifeform: {},
    edit_name: {},
    edit_name_description: {},
    email_tracking: {},
    eol: {},
    eol_expanded_review: {},
    eol_preview: {},
    index_name: {},
    index_name_description: {},
    inherit_classification: {},
    list_name_descriptions: {},
    list_names: {},
    make_description_default: {},
    map: {},
    merge_descriptions: {},
    name_descriptions_by_author: {},
    name_descriptions_by_editor: {},
    name_search: {},
    names_by_author: {},
    names_by_editor: {},
    names_by_user: {},
    needed_descriptions: {},
    next_name: {},
    next_name_description: {},
    observation_index: {},
    prev_name: {},
    prev_name_description: {},
    propagate_classification: {},
    propagate_lifeform: {},
    publish_description: {},
    refresh_classification: {},
    set_review_status: {},
    # show_name: {},
    show_name_description: {},
    show_past_name: {},
    show_past_name_description: {},
    test_index: {}
  },
  pivotal: {
    index: {}
  },
  project: {
    add_members: {},
    add_project: {},
    admin_request: {},
    change_member_status: {},
    destroy_project: {},
    edit_project: {},
    index_project: {},
    list_projects: {},
    next_project: {},
    prev_project: {},
    project_search: {}
    # show_project: {}
  },
  species_list: {
    add_observation_to_species_list: {},
    add_remove_observations: {},
    bulk_editor: {},
    clear_species_list: {},
    create_species_list: {},
    destroy_species_list: {},
    download: {},
    edit_species_list: {},
    index_species_list: {},
    list_species_lists: {},
    make_report: {},
    manage_projects: {},
    manage_species_lists: {},
    name_lister: {},
    next_species_list: {},
    post_add_remove_observations: {},
    prev_species_list: {},
    print_labels: {},
    remove_observation_from_species_list: {},
    # show_species_list: {},
    species_list_search: {},
    species_lists_by_title: {},
    species_lists_by_user: {},
    species_lists_for_project: {},
    upload_species_list: {}
  },
  support: {
    confirm: {},
    donate: {},
    donors: {},
    governance: {},
    letter: {},
    thanks: {},
    # Disable cop for legacy routes.
    # The routes are to very old pages that we might get rid of.
    wrapup_2011: {},
    wrapup_2012: {}
  },
  theme: {
    color_themes: {}
  },
  translation: {
    edit_translations: {},
    edit_translations_ajax_get: {},
    edit_translations_ajax_post: {}
  }
}.freeze

# -------------------------------------------------------
#  Deal with redirecting old routes to the modern ones.
# -------------------------------------------------------

ACTION_REDIRECTS = {
  create: {
    from: "/%<old_controller>s/create_%<model>s",
    to: "/%<new_controller>s/new",
    via: [:get, :post]
  },
  edit: {
    from: "/%<old_controller>s/edit_%<model>s/:id",
    to: "/%<new_controller>s/%<id>s/edit",
    via: [:get, :post]
  },
  destroy: {
    from: "/%<old_controller>s/destroy_%<model>s/:id",
    to: "/%<new_controller>s/%<id>s",
    via: [:patch, :post, :put]
  },
  controller: {
    from: "/%<old_controller>s",
    to: "/%<new_controller>s",
    via: [:get]
  },
  index: {
    from: "/%<old_controller>s/index_%<model>s",
    to: "/%<new_controller>s",
    via: [:get]
  },
  list: {
    from: "/%<old_controller>s/list_%<model>s",
    to: "/%<new_controller>s",
    via: [:get]
  },
  show: {
    from: "/%<old_controller>s/show_%<model>s/:id",
    to: "/%<new_controller>s/%<id>s",
    via: [:get]
  },
  show_past: {
    from: "/%<old_controller>s/show_past_%<model>s/:id",
    to: "/%<new_controller>s/%<id>s/show_past",
    via: [:get]
  }
}.freeze

# legacy actions that translate to standard CRUD actions
LEGACY_CRUD_ACTIONS = [
  :create, :edit, :destroy, :controller, :index, :list, :show
].freeze

# Array of "lookup_xxx" actions: these are all entry points mostly for
# external sites.  For example, it lets an external site link directly to
# the name page for "Amanita muscaria" without knowing the name_id of that
# name.
LOOKUP_ACTIONS = %w[
  lookup_accepted_name
  lookup_comment
  lookup_image
  lookup_location
  lookup_name
  lookup_observation
  lookup_project
  lookup_species_list
  lookup_user
].freeze

# redirect legacy MO actions to equivalent actions in the
# equivalent normalized controller
# Examples:
#  redirect_legacy_actions(old_controller: "article")
#  redirect_legacy_actions(
#    old_controller: "glossary",
#    new_controller: "glossary_terms",
#    actions: LEGACY_CRUD_ACTIONS - [:destroy] + [:show_past]
#  )
#
def redirect_legacy_actions(old_controller: "",
                            new_controller: old_controller&.pluralize,
                            model: new_controller&.singularize,
                            actions: LEGACY_CRUD_ACTIONS)
  actions.each do |action|
    data = ACTION_REDIRECTS[action]
    to_url = format(data[:to],
                    new_controller: new_controller,
                    model: model,
                    id: "%{id}")

    match(format(data[:from], old_controller: old_controller, model: model),
          to: redirect(path: to_url),
          via: data[:via])
  end
end

# ----------------------------
#  Helpers.
# ----------------------------

# Get an array of API endpoints for all versions of API.
def api_endpoints
  ACTIONS.keys.select { |controller| controller.to_s.start_with?("api") }.
    flat_map do |controller|
      ACTIONS[controller].keys.map { |action| [controller, action] }
    end
end

# declare routes for the actions in the ACTIONS hash
def route_actions_hash
  ACTIONS.each do |controller, actions|
    # Default action for any controller is "index".
    get(controller.to_s => "#{controller}#index")

    # Standard routes
    actions.each_key do |action|
      get("#{controller}/#{action}", controller: controller, action: action)
      match("#{controller}(/#{action}(/:id))",
            controller: controller,
            action: action,
            via: [:get, :post],
            id: /\d+/)
    end
  end
end

# -----------------------------------------------------
#  This is where our routes are actually established.
# -----------------------------------------------------

# Disable cop until there's time to reexamine block length
# Maybe we could define methods for logical chunks of this.
MushroomObserver::Application.routes.draw do # rubocop:todo Metrics/BlockLength
  if Rails.env.development?
    mount(GraphiQL::Rails::Engine, at: "/graphiql",
                                   graphql_path: "/graphql#execute")
  end

  if Rails.env.development? || Rails.env.test?
    # GraphQL development additions
    post("/graphql", to: "graphql#execute")
  end

  # Priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  # root 'welcome#index'

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically)
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #     get 'short'
  #     post 'toggle'
  #     end
  #
  #     collection do
  #     get 'sold'
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
  #     get 'recent', on: :collection
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

  # Default page is /rss_logs
  root "rss_logs#index"

  # Route /123 to /observations/123.
  get ":id" => "observations#show", id: /\d+/, as: "permanent_observation"

  # NOTE: The nesting below is necessary to get nice path helpers
  resource :account, only: [:new, :create], controller: "account"

  namespace :account do
    get("welcome")
    get("signup", to: "/account#new") # alternate path

    resource :login, only: [:new, :create], controller: "login"
    get("email_new_password", controller: "login")
    post("new_password_request", controller: "login")
    get("logout", controller: "login")
    get("test_autologin", controller: "login")

    resource :preferences, only: [:edit, :update]
    get("no_email/:id", to: "preferences#no_email", as: "no_email")

    resource :profile, only: [:edit, :update], controller: "profile"
    patch("profile/remove_image", controller: "profile") # alternate path

    resource :verify, only: [:new, :create], controller: "verifications"
    # Alternate path name for email verification
    get("verify(/:id)", to: "verifications#new", as: "verify_email")
    get("reverify", controller: "verifications")
    post("verify/resend_email(/:id)", to: "verifications#resend_email",
                                      as: "resend_verification_email")

    resources :api_keys, only: [:index, :create, :edit, :update]
    post("api_keys/:id/activate", to: "api_keys#activate",
                                  as: "activate_api_key")
    post("api_keys/remove", to: "api_keys#remove",
                            as: "remove_api_key")
  end

  # ----- Admin: resources and actions ------------------------------------
  namespace :admin do
    # controls turning admin mode on and off, and switching users
    resource :session, only: [:show, :edit, :update], controller: "session",
                       as: "mode"
    get("switch_users", to: "mode#edit") # alternate path

    resource :users, only: [:edit, :update, :destroy]
    resource :donations, only: [:new, :create, :edit, :update, :destroy]
    get("review_donations", to: "donations#edit") # alternate path
    resource :banner, only: [:edit, :update], controller: "banner"
    resource :blocked_ips, only: [:edit, :update]
    resource :add_user_to_group, only: [:new, :create],
                                 controller: "add_user_to_group"
    namespace :emails do
      resource :feature, only: [:new, :create], controller: "feature"
    end
  end

  # ----- Articles: standard actions --------------------------------------
  resources :articles, id: /\d+/

  # ----- Authors: standard actions ------------------------------------
  namespace :authors do
    resource :review, only: [:show, :create, :destroy], id: /\d+/
    resource :email_requests, only: [:new, :create]
  end

  # ----- Checklist: just the show --------------------------------------
  get "/checklist", to: "checklists#show"

  # ----- Collection Numbers: standard actions --------------------------------
  resources :collection_numbers do
    resource :remove_observation, only: [:update], module: :collection_numbers
  end

  # ----- Comments: standard actions --------------------------------------
  resources :comments

  # ----- Contributors: standard actions --------------------------------------
  resources :contributors, only: [:index]

  # ----- Emails: no resources, just forms ------------------------------------
  match("/emails/ask_observation_question(/:id)",
        to: "emails#ask_observation_question", via: [:get, :post], id: /\d+/,
        as: "emails_ask_observation_question")
  match("/emails/ask_user_question(/:id)",
        to: "emails#ask_user_question", via: [:get, :post], id: /\d+/,
        as: "emails_ask_user_question")
  match("/emails/ask_webmaster_question(/:id)",
        to: "emails#ask_webmaster_question", via: [:get, :post], id: /\d+/,
        as: "emails_ask_webmaster_question")
  match("/emails/commercial_inquiry(/:id)",
        to: "emails#commercial_inquiry", via: [:get, :post], id: /\d+/,
        as: "emails_commercial_inquiry")
  # match("/emails/features(/:id)",
  #       to: "emails#features", via: [:get, :post], id: /\d+/,
  #       as: "emails_features")
  match("/emails/merge_request(/:id)",
        to: "emails#merge_request", via: [:get, :post], id: /\d+/,
        as: "emails_merge_request")
  match("/emails/name_change_request(/:id)",
        to: "emails#name_change_request", via: [:get, :post], id: /\d+/,
        as: "emails_name_change_request")

  # ----- Export: no resources ------------------------------------
  get("/export/set_export_status(/:id)",
      to: "export#set_export_status",
      id: /\d+/, as: "export_set_export_status")
  get("/export/set_ml_status(/:id)",
      to: "export#set_ml_status",
      id: /\d+/, as: "export_set_ml_status")

  # ----- Glossary Terms: standard actions ------------------------------------
  resources :glossary_terms, id: /\d+/ do
    get "show_past", on: :member
  end

  # ----- Herbaria: standard actions -------------------------------------------
  namespace :herbaria do
    resources :curator_requests, only: [:new, :create]
    resources :curators, only: [:create, :destroy], id: /\d+/
    resources :merges, only: [:create]
    resources :nexts, only: [:show], id: /\d+/
  end
  resources :herbaria, id: /\d+/

  # ----- Herbarium Records: standard actions --------------------------------
  resources :herbarium_records do
    resource :remove_observation, only: [:update], module: :herbarium_records
  end

  # ----- Info: no resources, just forms and pages ----------------------------
  get("/info/how_to_help", to: "info#how_to_help")
  get("/info/how_to_use", to: "info#how_to_use")
  get("/info/intro", to: "info#intro")
  get("/info/news", to: "info#news")
  get("/info/search_bar_help", to: "info#search_bar_help")
  get("/info/site_stats", to: "info#site_stats")
  match("/info/textile_sandbox", to: "info#textile_sandbox", via: [:get, :post])
  get("/info/translators_note", to: "info#translators_note")

  resources :interests, only: [:index, :create, :update, :destroy]
  get "/interests/set_interest", to: "interests#set_interest",
                                 as: "set_interest"

  # ----- Javascript: utility actions  ----------------------------
  get("/javascript/turn_javascript_on", to: "javascript#turn_javascript_on")
  get("/javascript/turn_javascript_off", to: "javascript#turn_javascript_off")
  get("/javascript/turn_javascript_nil", to: "javascript#turn_javascript_nil")
  get("/javascript/hide_thumbnail_map", to: "javascript#hide_thumbnail_map")

  # ----- Observations: standard actions  ----------------------------
  namespace :observations do
    resources :downloads, only: [:new, :create]
  end

  resources :observations do
    resources :namings, only: [:new, :create, :edit, :update, :destroy],
                        shallow: true, controller: "observations/namings" do
      resources :votes, only: [:update, :show], as: "naming_vote",
                        param: :naming_id,
                        controller: "observations/namings/votes"
    end

    member do
      get("map", to: "observations/maps#show")
      get("suggestions", to: "observations/namings/suggestions#show",
                         as: "naming_suggestions_for")
    end
    collection do
      get("map", to: "observations/maps#index")
      get("print_labels", to: "observations/downloads#print_labels",
                          as: "print_labels_for")
    end
  end
  get("/observations/:id/species_lists/edit",
      to: "observations/species_lists#edit",
      as: "edit_observation_species_lists")
  match("/observations/:observation_id/species_lists/:id(/:commit)",
        to: "observations/species_lists#update",
        via: [:put, :patch],
        as: "observation_species_list")

  # ----- Policy: one route  --------------------------------------------------
  get("/policy/privacy")

  # ----- Publications: standard actions  -------------------------------------
  resources :publications

  # ----- RssLogs: standard actions ----------------------------------------
  # This route must go first, or it will try to match "rss" to an rss_log
  namespace :activity_logs, controller: "rss_logs" do
    get :rss, to: "/rss_logs#rss"
  end

  resources :activity_logs, only: [:show, :index], controller: "rss_logs"

  # ----- Searches: nonstandard actions --------------------------------------
  match("/search/pattern(/:id)",
        to: "search#pattern", via: [:get, :post], id: /\d+/,
        as: "search_pattern")
  match("/search/advanced(/:id)",
        to: "search#advanced", via: [:get, :post], id: /\d+/,
        as: "search_advanced")

  # ----- Sequences: standard actions ---------------------------------------
  resources :sequences, id: /\d+/

  # ----- Species Lists: standard actions -----------------------------------
  resources :species_lists, id: /\d+/ do
    resources :projects, only: [:edit, :update],
                         controller: "species_lists/projects"
    resources :uploads, only: [:new, :create],
                        controller: "species_lists/uploads"
    resources :downloads, only: [:new, :create],
                          controller: "species_lists/downloads"
  end
  get("/species_lists/:species_list/observations",
      to: "species_lists/observations#edit",
      as: "edit_species_list_observations")
  match("/species_lists/:species_list/observations/:commit",
        to: "species_lists/observations#update",
        via: [:put, :patch],
        as: "species_list_observations")

  # ----- Test pages  -------------------------------------------
  namespace :test_pages do
    resource :flash_redirection, only: [:show], controller: "flash_redirection"
  end

  # ----- Users: standard actions -------------------------------------------
  resources :users, id: /\d+/, only: [:index, :show]

  # ----- VisualModels: standard actions ------------------------------------
  resources :visual_models, id: /\d+/ do
    resources :visual_groups, id: /\d+/, shallow: true
  end

  # Temporary shorter path builders for non-CRUDified controllers SHOW

  # ----- Image:
  get("/image/show_image/:id", to: "image#show_image",
                               as: "show_image")
  # ----- Location:
  get("/location/show_location/:id", to: "location#show_location",
                                     as: "show_location")
  # ----- Name:
  get("/name/show_name/:id", to: "name#show_name",
                             as: "show_name")
  # ----- Project:
  get("/project/show_project/:id", to: "project#show_project",
                                   as: "show_project")

  # ----- end temporary show routes for path_builder with id ---------------

  # Short-hand notation for AJAX methods.
  # get "ajax/:action/:type/:id" => "ajax", constraints: { id: /\S.*/ }
  ACTIONS[:ajax].each_key do |action|
    get("ajax/#{action}/:type/:id",
        controller: "ajax", action: action, id: /\S.*/)
  end

  ##############################################################################
  ###
  ###
  ### LEGACY ACTION REDIRECTS ##################################################
  ###
  ###
  ### Note: Only public, bookmarkable GET routes, or routes appearing inside
  ### translation strings, need to be redirected.
  ### Form actions do not need redirections. The live site's forms will POST
  ### or PUT to current action routes.

  # ----- Articles: legacy action redirects
  redirect_legacy_actions(
    old_controller: "article", actions: [:controller, :show, :list, :index]
  )

  # ----- Authors: legacy action redirects
  get("/observer/author_request", to: redirect("/authors/email_request"))
  get("/observer/review_authors", to: redirect("/authors/review"))

  # ----- Checklist: legacy action redirects
  get("/observer/checklist", to: redirect("/checklist"))

  # ----- Emails: legacy action redirects
  get("/observer/ask_observation_question/:id",
      to: redirect(path: "/emails/ask_observation_question/%{id}"))
  get("/observer/ask_user_question/:id",
      to: redirect(path: "/emails/ask_user_question/%{id}"))
  get("/observer/ask_webmaster_question",
      to: redirect(path: "/emails/ask_webmaster_question"))
  get("/observer/commercial_inquiry/:id",
      to: redirect(path: "/emails/commercial_inquiry/%{id}"))
  get("/observer/email_merge_request",
      to: redirect(path: "/emails/merge_request"))
  get("/observer/email_name_change_request",
      to: redirect(path: "/emails/name_change_request"))

  # ----- Glossary Terms: legacy action redirects
  redirect_legacy_actions(
    old_controller: "glossary", new_controller: "glossary_terms",
    actions: [:controller, :show, :list, :index, :show_past]
  )

  # ----- Herbaria: legacy action redirects
  redirect_legacy_actions(
    old_controller: "herbarium", new_controller: "herbaria",
    actions: [:show, :list, :index]
  )

  # ----- Herbaria: nonstandard legacy action redirects
  get("/herbarium/herbarium_search", to: redirect("/herbaria"))
  get("/herbarium/index", to: redirect("/herbaria"))
  get("/herbarium/index_herbarium/:id", to: redirect("/herbaria?id=%{id}"))
  get("/herbarium/index_herbarium", to: redirect("/herbaria"))
  get("/herbarium/list_herbaria", to: redirect("/herbaria?flavor=all"))
  get("/herbarium/request_to_be_curator/:id",
      to: redirect("/herbaria/curator_requests/new?id=%{id}"))
  # Must be the final route in order to give the others priority
  get("/herbarium", to: redirect("/herbaria?flavor=nonpersonal"))

  # ----- Interests: legacy action redirects
  redirect_legacy_actions(
    old_controller: "interest", new_controller: "interests",
    actions: [:index]
  )

  # ----- Info: legacy action redirects ---------------------------
  get("/observer/how_to_help", to: redirect("/info/how_to_help"))
  get("/observer/how_to_use", to: redirect("/info/how_to_use"))
  get("/observer/intro", to: redirect("/info/intro"))
  get("/observer/news", to: redirect("/info/news"))
  get("/observer/search_bar_help", to: redirect("/info/search_bar_help"))
  get("/observer/show_site_stats", to: redirect("/info/site_stats"))
  get("/observer/textile", to: redirect("/info/textile_sandbox"))
  get("/observer/textile_sandbox", to: redirect("/info/textile_sandbox"))
  get("/observer/translators_note", to: redirect("/info/translators_note"))

  # ----- Observations: legacy action redirects ----------------------------
  get("/observer/create_observation", to: redirect("/observations/new"))
  get("/observer/observation_search", to: redirect("/observations"))
  get("/observer/advanced_search", to: redirect("/observations"))
  get("/observer/index_observation/:id", to: redirect("/observations?id=%{id}"))
  get("/observer/index_observation", to: redirect("/observations"))
  get("/observer/list_observations", to: redirect("/observations"))
  get("/observer/map_observation/:id", to: redirect("/observations/%{id}/map"))
  get("/observer/map_observations", to: redirect("/observations/map"))
  get("/observer/next_observation/:id",
      to: redirect("/observations/%{id}?flow=next"))
  get("/observer/prev_observation/:id",
      to: redirect("/observations/%{id}?flow=prev"))
  get("/observer/observations_of_look_alikes/:id",
      to: redirect("/observations?name=%{id}&look_alikes=1"))
  get("/observer/observations_of_related_taxa/:id",
      to: redirect("/observations?name=%{id}&related_taxa=1"))
  get("/observer/observations_of_name/:id",
      to: redirect("/observations?name=%{id}"))
  get("/observer/observations_by_user/:id",
      to: redirect("/observations?user=%{id}"))
  get("/observer/observations_at_location/:id",
      to: redirect("/observations?location=%{id}"))
  get("/observer/observations_at_where/:id",
      to: redirect("/observations?where=%{id}"))
  get("/observer/observations_for_project/:id",
      to: redirect("/observations?project=%{id}"))
  get("/observer/show_observation/:id",
      to: redirect("/observations/%{id}"))

  # ----- RssLogs: legacy action redirects ------------------------------
  get("/observer/index", to: redirect("/activity_logs"))
  get("/observer/list_rss_logs", to: redirect("/activity_logs"))
  get("/observer/index_rss_log/:id", to: redirect("/activity_logs?id=%{id}"))
  get("/observer/index_rss_log", to: redirect("/activity_logs"))
  get("/observer/show_rss_log/:id", to: redirect("/activity_logs/%{id}"))
  get("/observer/rss", to: redirect("/activity_logs/rss"))

  # ----- Sequences: legacy action redirects
  redirect_legacy_actions(
    old_controller: "sequence", new_controller: "sequences",
    actions: [:show, :index]
  )
  get("/sequence/create_sequence/:id",
      to: redirect("/sequences/new?obs_id=%{id}"))
  get("/sequence/edit_sequence/:id", to: redirect("/sequences/%{id}/edit"))
  # ----- Sequences: nonstandard legacy action redirects
  get("/sequence/list_sequences", to: redirect("/sequences?flavor=all"))

  # ----- Users: legacy action redirects  ----------------------------------
  get("/observer/user_search", to: redirect(path: "/users"))
  get("/observer/index_user/:id", to: redirect(path: "/users?id=%{id}"))
  get("/observer/index_user", to: redirect(path: "/users"))
  get("/observer/list_users", to: redirect(path: "/users"))
  get("/observer/users_by_contribution", to: redirect(path: "/contributors"))
  get("/observer/users_by_name", to: redirect("/users?by=name"))
  get("/observer/show_user/:id", to: redirect("/users/%{id}"))
  get("/observer/change_user_bonuses/:id", to: redirect("/users/%{id}/edit"))

  # ----- Search: legacy action redirects ---------------------------------
  get("/observer/pattern_search", to: redirect("/search/pattern"))
  get("/observer/advanced_search_form", to: redirect("/search/advanced"))

  ###
  ###
  ### END OF LEGACY ACTION REDIRECTS #####################################

  # Add support for PATCH and DELETE requests for API.
  api_endpoints.each do |controller, action|
    delete("#{controller}/#{action}", controller: controller, action: action)
    patch("#{controller}/#{action}", controller: controller, action: action)
  end

  # Accept non-numeric ids for the /lookups/lookup_xxx/id actions.
  LOOKUP_ACTIONS.each do |action|
    get("/lookups/#{action}(/:id)", to: "lookups##{action}", id: /\S.*/)
  end

  # declare routes for the actions in the ACTIONS hash
  route_actions_hash

  # routes for actions that Rails automatically creates from view templates
  MO.themes.each { |scheme| get "/theme/#{scheme}" }
end
