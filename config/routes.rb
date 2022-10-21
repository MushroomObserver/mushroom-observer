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
  account: {
    # activate_api_key: {},
    # api_keys: {},
    # create_api_key: {},
    # edit_api_key: {},
    # email_new_password: {},
    # login: {},
    # logout_user: {},
    # no_comment_email: { methods: [:get] },
    # no_comment_response_email: {},
    # no_commercial_email: {},
    # no_consensus_change_email: {},
    # no_email_comments_all: {},
    # no_email_comments_owner: {},
    # no_email_comments_response: {},
    # no_email_general_commercial: {},
    # no_email_general_feature: {},
    # no_email_general_question: {},
    # no_email_locations_admin: {},
    # no_email_locations_all: {},
    # no_email_locations_author: {},
    # no_email_locations_editor: {},
    # no_email_names_admin: {},
    # no_email_names_all: {},
    # no_email_names_author: {},
    # no_email_names_editor: {},
    # no_email_names_reviewer: {},
    # no_email_observations_all: {},
    # no_email_observations_consensus: {},
    # no_email_observations_naming: {},
    # no_feature_email: {},
    # no_name_change_email: {},
    # no_name_proposal_email: {},
    # no_question_email: {},
    # prefs: {},
    # profile: {},
    # remove_api_keys: {}
    # remove_image: {},
    # reverify: {},
    # send_verify: {},
    # signup: {},
    # test_autologin: {},
    # verify: {}
    # welcome: {}
  },
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
  collection_number: {
    collection_number_search: {},
    create_collection_number: {},
    destroy_collection_number: {},
    edit_collection_number: {},
    index_collection_number: {},
    list_collection_numbers: {},
    next_collection_number: {},
    observation_index: {},
    prev_collection_number: {},
    remove_observation: {},
    show_collection_number: {}
  },
  comment: {
    add_comment: {},
    comment_search: {},
    destroy_comment: {},
    edit_comment: {},
    index_comment: {},
    list_comments: {},
    next_comment: {},
    prev_comment: {},
    show_comment: {},
    show_comments_by_user: {},
    show_comments_for_target: {},
    show_comments_for_user: {}
  },
  herbarium_record: {
    create_herbarium_record: {},
    destroy_herbarium_record: {},
    edit_herbarium_record: {},
    herbarium_index: {},
    herbarium_record_search: {},
    index_herbarium_record: {},
    list_herbarium_records: {},
    next_herbarium_record: {},
    observation_index: {},
    prev_herbarium_record: {},
    remove_observation: {},
    show_herbarium_record: {}
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
    show_image: {},
    show_original: {},
    transform_image: {}
  },
  interest: {
    destroy_notification: {},
    list_interests: {},
    set_interest: {}
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
    show_location: {},
    show_location_description: {},
    show_past_location: {},
    show_past_location_description: {}
  },
  name: {
    adjust_permissions: {},
    advanced_search: {},
    approve_name: {},
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
    show_name: {},
    show_name_description: {},
    show_past_name: {},
    show_past_name_description: {},
    test_index: {}
  },
  naming: {
    create: {},
    destroy: {},
    edit: {}
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
    project_search: {},
    show_project: {}
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
    show_species_list: {},
    species_list_search: {},
    species_lists_by_title: {},
    species_lists_by_user: {},
    species_lists_for_project: {},
    upload_species_list: {}
  },
  support: {
    confirm: {},
    create_donation: {},
    donate: {},
    donors: {},
    governance: {},
    letter: {},
    review_donations: {},
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
  },
  vote: {
    cast_vote: {},
    cast_votes: {},
    refresh_vote_cache: {},
    show_votes: {}
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

  # NOTE: this nesting or lack thereof is necessary to get nice path helpers
  resource :account, only: [:new, :create]

  namespace :account do
    get("welcome")
    get("signup", to: "/account#new")

    resource :login, only: [:new, :create], controller: "login"
    get("email_new_password", controller: "login")
    post("new_password_request", controller: "login")
    get("logout", controller: "login")
    get("test_autologin", controller: "login")

    resource :preferences, only: [:edit, :update]
    get("no_email", controller: "preferences")

    resource :profile, only: [:edit, :update], controller: "profile"
    patch("profile/remove_image", controller: "profile")

    resource :verify, only: [:new, :create], controller: "verifications"
    # match("verify", via: [:get, :post], controller: "verifications")
    get("reverify", controller: "verifications")
    post("send_verify", controller: "verifications")

    resources :api_keys, only: [:index, :create, :edit, :update]
    post("api_keys/:id/activate", to: "api_keys#activate",
                                  as: "activate_api_key")
    post("api_keys/remove", to: "api_keys#remove",
                            as: "remove_api_key")
    # get("api_keys", to: "api_keys#index")
  end

  # ----- Admin: no resources, just actions ------------------------------------
  namespace :admin do
    resource :turn_admin_on, only: [:show], controller: "turn_on"
    resource :turn_admin_off, only: [:show], controller: "turn_off"
    resource :change_banner, only: [:edit, :udpate], controller: "change_banner"
    resource :switch_users, only: [:new, :create]
    resource :blocked_ips, only: [:show]
    resource :add_user_to_group, only: [:new, :create],
                                 controller: "add_user_to_group"
  end

  # match("/admin/turn_admin_on", to: "admin#turn_admin_on", via: [:get, :post])
  # match("/admin/turn_admin_off", to: "admin#turn_admin_off", via: [:get, :post])
  match("/admin/create_alert", to: "admin#create_alert", via: [:get, :post])
  # match("/admin/change_banner", to: "admin#change_banner", via: [:get, :post])
  match("/admin/test_flash_redirection",
        to: "admin#test_flash_redirection", via: [:get, :post])
  # match("/admin/add_user_to_group",
  #       to: "admin#add_user_to_group", via: [:get, :post])
  # match("/admin/blocked_ips", to: "admin#blocked_ips", via: [:get, :post])
  match("/admin/destroy_user", to: "admin#destroy_user", via: [:get, :post])
  # match("/admin/switch_users", to: "admin#switch_users", via: [:get, :post])

  # ----- Articles: standard actions --------------------------------------
  resources :articles, id: /\d+/

  # ----- Authors: no resources, just forms ------------------------------------
  match("/authors/email_request(/:id)",
        to: "authors#email_request", via: [:get, :post], id: /\d+/,
        as: "authors_email_request")
  match("/authors/review(/:id)",
        to: "authors#review", via: [:get, :post], id: /\d+/,
        as: "authors_review")

  # ----- Checklist: just the show --------------------------------------
  get "/checklist", to: "checklists#show"

  # ----- Contributors: standard actions --------------------------------------
  resources :contributors, only: [:index]

  # ----- Emails: no resources, just forms -------------------------------------
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
  match("/emails/features(/:id)",
        to: "emails#features", via: [:get, :post], id: /\d+/,
        as: "emails_features")
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

  # ----- Info: no resources, just forms and pages ----------------------------
  get("/info/how_to_help", to: "info#how_to_help")
  get("/info/how_to_use", to: "info#how_to_use")
  get("/info/intro", to: "info#intro")
  get("/info/news", to: "info#news")
  get("/info/search_bar_help", to: "info#search_bar_help")
  get("/info/site_stats", to: "info#site_stats")
  match("/info/textile_sandbox", to: "info#textile_sandbox", via: [:get, :post])
  get("/info/translators_note", to: "info#translators_note")

  # ----- Javascript: utility actions  ----------------------------
  get("/javascript/turn_javascript_on", to: "javascript#turn_javascript_on")
  get("/javascript/turn_javascript_off", to: "javascript#turn_javascript_off")
  get("/javascript/turn_javascript_nil", to: "javascript#turn_javascript_nil")
  get("/javascript/hide_thumbnail_map", to: "javascript#hide_thumbnail_map")

  # ----- Observations: standard actions  ----------------------------
  resources :observations do
    member do
      get("map")
      get("suggestions")
    end
    collection do
      get("map")
      get("download")
      post("download")
      get("print_labels")
      post("print_labels")
    end
  end

  # ----- Policy: one route  --------------------------------------------------
  get("/policy/privacy")

  # ----- Publications: standard actions  -------------------------------------
  resources :publications

  # ----- RssLogs: nonstandard actions ----------------------------------------
  # These routes must go before resources, or it will try to match
  # "rss" to an rss_log
  # resources :rss_logs, only: [:show, :index]
  get("/activity_logs/rss", to: "rss_logs#rss", as: "activity_logs_rss")
  get("/activity_logs", to: "rss_logs#index", as: "activity_logs")
  get("/activity_logs/:id", to: "rss_logs#show", as: "activity_log")

  # ----- Searches: nonstandard actions --------------------------------------
  match("/search/pattern(/:id)",
        to: "search#pattern", via: [:get, :post], id: /\d+/,
        as: "search_pattern")
  match("/search/advanced(/:id)",
        to: "search#advanced", via: [:get, :post], id: /\d+/,
        as: "search_advanced")

  # ----- Sequences: standard actions ---------------------------------------
  resources :sequences, id: /\d+/

  # ----- Users: standard actions -------------------------------------------
  resources :users, id: /\d+/, only: [:index, :show, :edit, :update]

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
  get("/account/add_user_to_group", to: redirect("/admin/add_user_to_group"))
  get("/account/blocked_ips", to: redirect("/admin/blocked_ips"))
  get("/account/add_user_to_group", to: redirect("/admin/add_user_to_group"))
  get("/account/destroy_user", to: redirect("/admin/destroy_user"))
  get("/account/switch_users", to: redirect("/admin/switch_users"))

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
  get("/observer/email_features",
      to: redirect(path: "/emails/features"))
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

  # ----- Javascript: legacy action redirects ----------------------------
  get("/observer/hide_thumbnail_map/:id",
      to: redirect("/javascript/hide_thumbnail_map?id=%{id}"))

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

  # Accept non-numeric ids for the /observer/lookup_xxx/id actions.
  LOOKUP_ACTIONS.each do |action|
    get("lookups/#{action}(/:id)", to: "lookups##{action}", id: /\S.*/)
    get("/observer/#{action}(/:id)", to: "lookups##{action}", id: /\S.*/)
  end

  # declare routes for the actions in the ACTIONS hash
  route_actions_hash

  # routes for actions that Rails automatically creates from view templates
  MO.themes.each { |scheme| get "theme/#{scheme}" }
end
