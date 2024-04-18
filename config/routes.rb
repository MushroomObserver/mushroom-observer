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
  api: {
    api_keys: {},
    collection_numbers: {},
    comments: {},
    external_links: {},
    external_sites: {},
    field_slips: {},
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
    field_slips: {},
    herbaria: {},
    herbarium_records: {},
    images: {},
    locations: {},
    location_descriptions: {},
    names: {},
    name_descriptions: {},
    observations: {},
    projects: {},
    sequences: {},
    species_lists: {},
    users: {}
  },
  support: {
    confirm: {},
    donate: {},
    donors: {},
    governance: {},
    letter: {},
    thanks: {},
    # Disable cop for legacy routes.
    # The routes are two very old pages that we might get rid of.
    # rubocop:disable Naming/VariableNumber
    wrapup_2011: {},
    wrapup_2012: {}
    # rubocop:enable Naming/VariableNumber
  },
  theme: {
    color_themes: {}
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
  lookup_glossary_term
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
#
#  To access paths in the console:
#    include Rails.application.routes.url_helpers
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

  # Default page "/" is /observations ordered by: :rss_log
  root "observations#index"

  # Route /123 to /observations/123.
  get ":id" => "observations#show", id: /\d+/, as: "permanent_observation"

  # NOTE: The nesting below is necessary to get nice path helpers
  resource :account, only: [:new, :create], controller: "account"

  namespace :account do
    get("welcome")
    get("signup", to: "/account#new") # alternate path

    resource :login, only: [:new, :create], controller: "login"
    unresourced_login_gets = %w[email_new_password test_autologin].freeze
    unresourced_login_gets.each { |action| get(action, controller: "login") }
    post("logout", controller: "login")
    post("new_password_request", controller: "login")

    resource :preferences, only: [:edit, :update]
    get("no_email/:id", to: "preferences#no_email", as: "no_email")

    resource :profile, only: [:edit, :update], controller: "profile"
    get("profile/images", to: "profile/images#reuse",
                          as: "profile_select_image")
    post("profile/images(/:id)", to: "profile/images#attach",
                                 as: "profile_update_image")
    put("profile/images(/:id)", to: "profile/images#detach",
                                as: "profile_remove_image")

    resource :verify, only: [:new, :create], controller: "verifications"
    # Alternate path name for email verification
    get("verify(/:id)", to: "verifications#new", as: "verify_email")
    get("reverify", controller: "verifications")
    post("verify/resend_email(/:id)", to: "verifications#resend_email",
                                      as: "resend_verification_email")

    resources :api_keys, only: [:index, :create, :edit, :update, :destroy]
    patch("api_keys/:id/activate", to: "api_keys#activate",
                                   as: "activate_api_key")
  end

  # ----- Admin: resources and actions ------------------------------------
  namespace :admin do
    # controls turning admin mode on and off, and switching users
    resource :session, only: [:create, :edit, :update], controller: "session",
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
      resource :features, only: [:new, :create], controller: "features"
      resource :webmaster_questions, only: [:new, :create],
                                     controller: "webmaster_questions"
      resource :merge_requests, only: [:new, :create],
                                controller: "merge_requests"
      resource :name_change_requests, only: [:new, :create],
                                      controller: "name_change_requests"
    end
  end

  # ----- Articles: standard actions --------------------------------------
  resources :articles, id: /\d+/

  # ----- Autocompleters: fetch get ------------------------------------
  get "/autocompleters/new/:type/:id", to: "autocompleters#new"

  # ----- Checklist: just the show --------------------------------------
  get "/checklist", to: "checklists#show"

  # ----- Collection Numbers: standard actions --------------------------------
  resources :collection_numbers do
    resource :remove_observation, only: [:edit, :update],
                                  module: :collection_numbers
  end

  # ----- Comments: standard actions --------------------------------------
  resources :comments

  # ----- Contributors: standard actions --------------------------------------
  resources :contributors, only: [:index]

  # ----- Descriptions: namespaced actions -------------------------------------
  namespace :descriptions, as: "description" do
    resource :authors, only: [:show, :create, :destroy], id: /\d+/
    resource :author_requests, only: [:new, :create]
  end

  # ----- Export: no resources ------------------------------------
  get("/export/set_export_status(/:id)",
      to: "export#set_export_status",
      id: /\d+/, as: "export_set_export_status")
  get("/export/set_ml_status(/:id)",
      to: "export#set_ml_status",
      id: /\d+/, as: "export_set_ml_status")

  # ----- Glossary Terms: standard actions ------------------------------------
  resources :glossary_terms, id: /\d+/ do
    member do
      get("images/reuse", to: "glossary_terms/images#reuse",
                          as: "reuse_images_for")
      post("images/attach", to: "glossary_terms/images#attach",
                            as: "attach_image_to")
      get("images/remove", to: "glossary_terms/images#remove",
                           as: "remove_images_from")
      put("images/detach", to: "glossary_terms/images#detach",
                           as: "detach_image_from")
      get("versions", to: "glossary_terms/versions#show", as: "version_of")
    end
  end

  # ----- Field Slip Records: standard actions --------------------------------
  resources :field_slips
  get("qr/:id", to: "field_slips#show", id: /.*[^\d.-].*/)

  # ----- Field Slip Job Trackers: show for json -------------------------------
  resources :field_slip_job_trackers, only: [:show]

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
    resource :remove_observation, only: [:edit, :update],
                                  module: :herbarium_records
  end

  # ----- Images: Namespace differences are for memorable path names
  namespace :images do
    put("/purge_filenames", to: "/images/filenames#update",
                            as: "bulk_filename_purge")
    get("/licenses/edit", to: "/images/licenses#edit",
                          as: "edit_licenses")
    put("/licenses", to: "/images/licenses#update",
                     as: "license_updater")
    get("/votes/anonymity", to: "/images/votes/anonymity#edit",
                            as: "edit_vote_anonymity")
    put("/votes/anonymity", to: "/images/votes/anonymity#update",
                            as: "bulk_vote_anonymity_updater")
  end
  resources :images, only: [:index, :show, :destroy] do
    member do
      put("transform", to: "images/transformations#update", as: "transform")
      get("exif", to: "images/exif#show", as: "exif")
      put("export", to: "images/exports#update", as: "export")
      get("emails/new", to: "images/emails#new",
                        as: "new_commercial_inquiry_for")
      post("emails", to: "images/emails#create",
                     as: "send_commercial_inquiry_for")
    end
    put("/vote", to: "images/votes#update", as: "vote")
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

  # ----- Locations: a lot of actions  ----------------------------
  resources :locations, id: /\d+/, shallow: true do
    member do
      put("reverse_name_order", to: "locations/reverse_name_order#update")
      get("versions", to: "locations/versions#show", as: "version_of")
    end
    resources :descriptions, module: :locations, shallow_path: :locations,
                             shallow_prefix: "location", except: :index do
      member do
        put("default", to: "descriptions/defaults#update", as: "make_default")
        get("merges/new", to: "descriptions/merges#new", as: "new_merge")
        post("merges", to: "descriptions/merges#create", as: "merge")
        get("moves/new", to: "descriptions/moves#new", as: "new_move")
        post("moves", to: "descriptions/moves#create", as: "move")
        get("versions", to: "descriptions/versions#show", as: "version_of")
      end
    end
  end
  # Unlike a resource route :index, this needs a special name and optional id.
  # MO doesn't index descriptions by parent_id, we index `all` e.g. by_author.
  get("locations(/:location_id)/descriptions",
      to: "locations/descriptions#index", as: "location_descriptions_index")
  # Location Countries: show
  get("locations(/:id)/countries", to: "locations/countries#index",
                                   as: "location_countries")
  # Location Help: show
  get("locations/help", to: "locations/help#show")
  # Map Locations: show
  get("locations/map", to: "locations/maps#show", as: "map_locations")

  # ----- Names: a lot of actions  ----------------------------
  resources :names, id: /\d+/, shallow: true do
    # These routes are for dealing with name attributes.
    # They're not `resources` because they don't have their own IDs.
    # Note that `member` routes end with the controller singular, e.g. "name"
    member do
      # classification
      get("classification/edit", to: "names/classification#edit",
                                 as: "edit_classification_of")
      match("classification", to: "names/classification#update",
                              via: [:put, :patch], as: "classification_of")
      get("classification/inherit/new", to: "names/classification/inherit#new",
                                        as: "form_to_inherit_classification_of")
      post("classification/inherit", to: "names/classification/inherit#create",
                                     as: "inherit_classification_of")
      put("classification/propagate",
          to: "names/classification/propagate#update",
          as: "propagate_classification_of")
      put("classification/refresh", to: "names/classification/refresh#update",
                                    as: "refresh_classification_of")
      # lifeforms
      get("lifeforms/edit", to: "names/lifeforms#edit", as: "edit_lifeform_of")
      match("lifeforms", to: "names/lifeforms#update", via: [:put, :patch],
                         as: "lifeform_of")
      get("lifeforms/propagate/edit", to: "names/lifeforms/propagate#edit",
                                      as: "form_to_propagate_lifeform_of")
      put("lifeforms/propagate", to: "names/lifeforms/propagate#update",
                                 as: "propagate_lifeform_of")
      # map
      get("map", to: "names/maps#show")
      # synonyms
      get("synonyms/edit", to: "names/synonyms#edit", as: "edit_synonyms_of")
      match("synonyms", to: "names/synonyms#update", via: [:put, :patch],
                        as: "synonyms_of")
      get("synonyms/approve/new", to: "names/synonyms/approve#new",
                                  as: "form_to_approve_synonym_of")
      post("synonyms/approve", to: "names/synonyms/approve#create",
                               as: "approve_synonym_of")
      get("synonyms/deprecate/new", to: "names/synonyms/deprecate#new",
                                    as: "form_to_deprecate_synonym_of")
      post("synonyms/deprecate", to: "names/synonyms/deprecate#create",
                                 as: "deprecate_synonym_of")
      # trackers
      get("trackers/new", to: "names/trackers#new", as: "new_tracker_of")
      post("trackers", to: "names/trackers#create")
      # edit: there's no tracker id because you can only have one per name
      get("trackers/edit", to: "names/trackers#edit", as: "edit_tracker_of")
      match("trackers", to: "names/trackers#update", via: [:put, :patch])
      # versions
      get("versions", to: "names/versions#show", as: "version_of")
    end
    resources :descriptions, module: :names, shallow_path: :names,
                             shallow_prefix: "name", except: :index do
      member do
        put("default", to: "descriptions/defaults#update", as: "make_default")
        get("merges/new", to: "descriptions/merges#new", as: "new_merge")
        post("merges", to: "descriptions/merges#create", as: "merge")
        get("moves/new", to: "descriptions/moves#new", as: "new_move")
        post("moves", to: "descriptions/moves#create", as: "move")
        put("publish", to: "descriptions/publish#update")
        get("permissions/edit", to: "descriptions/permissions#edit",
                                as: "edit_permissions")
        put("permissions", to: "descriptions/permissions#update")
        put("review_status", to: "descriptions/review_status#update")
        get("versions", to: "descriptions/versions#show", as: "version_of")
      end
    end
  end
  # Unlike a resource route :index, this needs a special name and optional id.
  # MO doesn't index descriptions by parent_id, we index `all` e.g. by_author.
  get("names(/:name_id)/descriptions",
      to: "names/descriptions#index", as: "name_descriptions_index")
  # Test Index
  get("names/test_index", to: "names#test_index", as: "names_test_index")
  # Names Map: show:
  get("names/map", to: "names/maps#show", as: "map_names")
  # Approve Name Tracker: GET endpoint for admin email links
  get("names/trackers/:id/approve", to: "names/trackers/approve#new",
                                    as: "approve_name_tracker")
  # Name EOL Data: show:
  get("names/eol", to: "names/eol_data#show", as: "names_eol_data")
  get("names/eol_preview", to: "names/eol_data/preview#show",
                           as: "names_eol_preview")
  get("names/eol_expanded_review", to: "names/eol_data/expanded_review#show",
                                   as: "names_eol_expanded_review")

  # ----- Observations: standard actions  ----------------------------
  namespace :observations do
    resources :downloads, only: [:new, :create]

    # Not under resources :observations because the obs doesn't have an id yet
    get("images/uploads/new", to: "images/uploads#new",
                              as: "new_image_upload_for")
    post("images/uploads", to: "images/uploads#create",
                           as: "upload_image_for")
  end

  resources :observations do
    resources :namings, only: [:index, :new, :create, :edit, :update, :destroy],
                        controller: "observations/namings" do
      resources :votes, only: [:create, :update, :index],
                        controller: "observations/namings/votes"
    end

    member do
      resources :external_links,
                only: [:new, :create, :edit, :update, :destroy],
                shallow: true, controller: "observations/external_links"

      get("map", to: "observations/maps#show")
      get("suggestions", to: "observations/namings/suggestions#show",
                         as: "naming_suggestions_for")
      get("emails/new", to: "observations/emails#new",
                        as: "new_question_for")
      post("emails", to: "observations/emails#create",
                     as: "send_question_for")
      get("images/new", to: "observations/images#new",
                        as: "new_image_for")
      post("images", to: "observations/images#create",
                     as: "create_image_for")
      get("images/reuse", to: "observations/images#reuse",
                          as: "reuse_images_for")
      post("images/attach", to: "observations/images#attach",
                            as: "attach_image_to")
      get("images/remove", to: "observations/images#remove",
                           as: "remove_images_from")
      put("images/detach", to: "observations/images#detach",
                           as: "detach_images_from")
    end

    collection do
      get("map", to: "observations/maps#index")
      post("print_labels", to: "observations/downloads#print_labels",
                           as: "print_labels_for")
      get("identify", to: "observations/identify#index", as: "identify")
      # Options for correlating an "undefined" +where+ to a Location: form
      get("locations", to: "observations/locations#edit",
                       as: "matching_locations_for")
      # Assign Observation (matching :where) to a Location: update
      patch("assign_location", to: "observations/locations#update",
                               as: "assign_location_to")
    end
  end

  # NOTE: the intentional "backwards" param specificity here:
  get("/observations/:id/species_lists/edit",
      to: "observations/species_lists#edit",
      as: "edit_observation_species_lists")
  match("/observations/:id/species_lists/:species_list_id(/:commit)",
        to: "observations/species_lists#update",
        via: [:put, :patch],
        as: "observation_species_list")
  # These are in observations because they share private methods with
  # :new and :create, which are currently observation-specific
  get("/images/:id/edit", to: "observations/images#edit", as: "edit_image")
  match("/images/:id", to: "observations/images#update", via: [:put, :patch])

  resources :observation_views, only: :update

  # ----- Policy: one route  --------------------------------------------------
  get("/policy/privacy")

  resources :projects do
    resources :admin_requests, only: [:new, :create],
                               controller: "projects/admin_requests"
    resources :field_slips, only: [:new, :create],
                            controller: "projects/field_slips"
    resources :members, only: [:new, :create, :edit, :update, :index],
                        controller: "projects/members", param: :candidate
    resources :violations, only: [:index], controller: "projects/violations"
  end
  # resourceful route won't work because it requires an additional id
  put("/projects/:project_id/violations", to: "projects/violations#update",
                                          as: "project_violations_update")

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
  resources :species_lists, id: /\d+/

  put("/species_lists/:id/clear", to: "species_lists#clear",
                                  as: "clear_species_list")

  get("/species_lists/name_lister/new", to: "species_lists/name_lists#new",
                                        as: "new_species_list_name_lister")
  post("/species_lists/name_lister", to: "species_lists/name_lists#create",
                                     as: "species_list_name_lister")
  get("/species_lists/:id/uploads/new", to: "species_lists/uploads#new",
                                        as: "new_species_list_upload")
  post("/species_lists/:id/uploads", to: "species_lists/uploads#create",
                                     as: "species_list_uploads")
  get("/species_lists/:id/downloads/new", to: "species_lists/downloads#new",
                                          as: "new_species_list_download")
  post("/species_lists/:id/downloads", to: "species_lists/downloads#create",
                                       as: "species_list_downloads")
  post("/species_lists/:id/downloads/print_labels",
       to: "species_lists/downloads#print_labels",
       as: "species_list_download_print_labels")
  get("/species_lists/observations/edit",
      to: "species_lists/observations#edit",
      as: "edit_species_list_observations")
  match("/species_lists/observations(/:commit)",
        to: "species_lists/observations#update",
        via: [:put, :patch],
        as: "species_list_observations")
  get("/species_lists/:id/projects",
      to: "species_lists/projects#edit",
      as: "edit_species_list_projects")
  match("/species_lists/:id/projects",
        to: "species_lists/projects#update",
        via: [:put, :patch],
        as: "species_list_projects")

  # ----- Test if server is up  -------------------------------------
  resources :test, only: [:index], controller: "test"

  # ----- Test pages  -------------------------------------------
  namespace :test_pages do
    resource :flash_redirection, only: [:show], controller: "flash_redirection"
  end

  # ----- Translations: standard actions  -------------------------------------
  resources :translations, only: [:index, :edit, :update]

  # ----- Users: standard actions -------------------------------------------
  resources :users, id: /\d+/, only: [:index, :show] do
    member do
      get("emails/new", to: "users/emails#new",
                        as: "new_question_for")
      post("emails", to: "users/emails#create",
                     as: "send_question_for")
    end
  end

  # ----- VisualModels: standard actions ------------------------------------
  resources :visual_models, id: /\d+/ do
    resources :visual_groups, id: /\d+/, shallow: true
  end

  match("/visual_groups/:visual_group_id/images/:id",
        to: "visual_groups/images#update",
        via: [:put, :patch],
        as: "visual_group_image")

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
      to: redirect(path: "/observations/%{id}/emails/new"))
  get("/observer/ask_user_question/:id",
      to: redirect(path: "/users/%{id}/emails/new"))
  get("/observer/ask_webmaster_question",
      to: redirect(path: "/admin/emails/webmaster_questions/new"))
  get("/observer/commercial_inquiry/:id",
      to: redirect(path: "/images/%{id}/emails/new"))
  get("/observer/email_merge_request",
      to: redirect(path: "/admin/emails/merge_requests/new"))
  get("/observer/email_name_change_request",
      to: redirect(path: "/admin/emails/name_change_requests/new"))

  # ----- Glossary Terms: legacy action redirects
  redirect_legacy_actions(
    old_controller: "glossary", new_controller: "glossary_terms",
    actions: [:controller, :show, :list, :index]
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

  # ----- Images: legacy action redirects
  redirect_legacy_actions(
    old_controller: "image", new_controller: "images",
    actions: [:index, :show]
  )

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

  # ----- Names: legacy action redirects -----------------------------------
  get("name/eol", to: redirect("names/eol_data#show"))
  get("name/name_search", to: redirect(path: "names"))

  # ----- Lookups: legacy action redirects ---------------------------
  # The only legacy lookup that was ok'd for use by external sites
  get("/observer/lookup_name(/:id)", to: "lookups#lookup_name", id: /\S.*/)

  # ----- Observations: legacy action redirects ----------------------------
  get("/observer/create_observation", to: redirect("/observations/new"))
  get("/observer/observation_search", to: redirect(path: "/observations"))
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

  # ----- SpeciesLists: legacy action redirects
  redirect_legacy_actions(
    old_controller: "species_list", new_controller: "species_lists",
    actions: [:show]
  )
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

  # ----- ActionCable: mount the server -------------------------------------
  # mount ActionCable.server => "/cable"

  # routes for actions that Rails automatically creates from view templates
  MO.themes.each { |scheme| get "/theme/#{scheme}" }
end
