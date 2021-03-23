# frozen_string_literal: true

# Nested hash of permissible controllers and actions. Each entry as follows,
# with missing element meaning use default
# controller: {    # hash of controller ctions
#   action_name: {    # hash of attributes for this action
#     methods:  (array),  # allowed HTML methods, as symbols
#                         # methods key omitted => default: [:get, :post]
#     segments: (string), # expected segments, with leading slash(es)
#                         # segments key omitted => default: "/:id"
#                         # blank string means no segments allowed
#     id_constraint: (string|regexp)  # any constraint on id, default: /d+/
#   }
# }
ACTIONS = {
  account: {
    activate_api_key: {},
    add_user_to_group: {},
    api_keys: {},
    blocked_ips: {},
    create_alert: {},
    create_api_key: {},
    destroy_user: {},
    edit_api_key: {},
    email_new_password: {},
    login: {},
    logout_user: {},
    manager: {},
    no_comment_email: { methods: [:get] },
    no_comment_response_email: {},
    no_commercial_email: {},
    no_consensus_change_email: {},
    no_email_comments_all: {},
    no_email_comments_owner: {},
    no_email_comments_response: {},
    no_email_general_commercial: {},
    no_email_general_feature: {},
    no_email_general_question: {},
    no_email_locations_admin: {},
    no_email_locations_all: {},
    no_email_locations_author: {},
    no_email_locations_editor: {},
    no_email_names_admin: {},
    no_email_names_all: {},
    no_email_names_author: {},
    no_email_names_editor: {},
    no_email_names_reviewer: {},
    no_email_observations_all: {},
    no_email_observations_consensus: {},
    no_email_observations_naming: {},
    no_feature_email: {},
    no_name_change_email: {},
    no_name_proposal_email: {},
    no_question_email: {},
    prefs: {},
    profile: {},
    remove_api_keys: {},
    remove_image: {},
    reverify: {},
    send_verify: {},
    signup: {},
    switch_users: {},
    test_autologin: {},
    test_flash: {},
    turn_admin_off: {},
    turn_admin_on: {},
    verify: {},
    welcome: {}
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
  observer: {
    advanced_search: {},
    advanced_search_form: {},
    ask_observation_question: {},
    ask_user_question: {},
    ask_webmaster_question: {},
    author_request: {},
    change_banner: {},
    change_user_bonuses: {},
    checklist: {},
    commercial_inquiry: {},
    create_observation: {},
    destroy_observation: {},
    download_observations: {},
    edit_observation: {},
    email_features: {},
    email_merge_request: {},
    email_name_change_request: {},
    guess: {},
    hide_thumbnail_map: {},
    how_to_help: {},
    how_to_use: {},
    ilist_users: {},
    index: {},
    index_observation: {},
    index_rss_log: {},
    index_user: {},
    interview: {},
    intro: {},
    letter_to_community: {},
    list_observations: {},
    list_rss_logs: {},
    list_users: {},
    lookup_accepted_name: {},
    lookup_comment: {},
    lookup_image: {},
    lookup_location: {},
    lookup_name: {},
    lookup_observation: {},
    lookup_project: {},
    lookup_species_list: {},
    lookup_user: {},
    map_observation: {},
    map_observations: {},
    news: {},
    next_observation: {},
    next_rss_log: {},
    next_user: {},
    observation_search: {},
    observations_at_location: {},
    observations_at_where: {},
    observations_by_name: {},
    observations_by_user: {},
    observations_for_project: {},
    observations_of_look_alikes: {},
    observations_of_name: {},
    observations_of_related_taxa: {},
    pattern_search: {},
    prev_observation: {},
    prev_rss_log: {},
    prev_user: {},
    print_labels: {},
    recalc: {},
    review_authors: {},
    rss: {},
    search_bar_help: {},
    set_export_status: {},
    show_location_observations: {},
    show_notifications: {},
    show_obs: {},
    show_observation: {},
    show_rss_log: {},
    show_site_stats: {},
    show_user: {},
    suggestions: {},
    test_flash_redirection: {},
    textile: {},
    textile_sandbox: {},
    translators_note: {},
    turn_javascript_nil: {},
    turn_javascript_off: {},
    turn_javascript_on: {},
    user_search: {},
    users_by_contribution: {},
    users_by_name: {},
    w3c_tests: {},
    wrapup_2011: {}
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
  publications: {
    create: {},
    destroy: {},
    edit: {},
    index: {},
    new: {},
    show: {},
    update: {}
  },
  sequence: {
    create_sequence: {},
    destroy_sequence: {},
    edit_sequence: {},
    index_sequence: {},
    list_sequences: {},
    next_sequence: {},
    observation_index: {},
    prev_sequence: {},
    sequence_search: {},
    show_sequence: {}
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

AJAX_ACTIONS = %w[
  api_key
  auto_complete
  exif
  export
  external_link
  geocode
  old_translation
  pivotal
  multi_image_template
  create_image_object
  vote
].freeze

LOOKUP_XXX_ID_ACTIONS = %w[
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
                    # Rails routes currently only accept template tokens
                    id: "%{id}") # rubocop:disable Style/FormatStringToken

    match(format(data[:from], old_controller: old_controller, model: model),
          to: redirect(path: to_url),
          via: data[:via])
  end
end

# declare routes for the actions in the ACTIONS hash
def route_actions_hash
  ACTIONS.each do |controller, actions|
    # Default action for any controller is "index".
    get controller.to_s => "#{controller}#index"

    # Standard routes
    actions.each_key do |action|
      get "#{controller}/#{action}", controller: controller, action: action
      match "#{controller}(/#{action}(/:id))",
            controller: controller,
            action: action,
            via: [:get, :post],
            id: /\d+/
    end
  end
end

MushroomObserver::Application.routes.draw do
  get "policy/privacy"
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

  # Default page is /observer/list_rss_logs.
  root "observer#list_rss_logs"

  # Route /123 to /observer/show_observation/123.
  get ":id" => "observer#show_observation", id: /\d+/

  resources :articles, id: /\d+/
  redirect_legacy_actions(old_controller: "article")

  resources :glossary_terms, id: /\d+/ do
    get "show_past", on: :member
  end
  redirect_legacy_actions(
    old_controller: "glossary", new_controller: "glossary_terms",
    actions: LEGACY_CRUD_ACTIONS - [:destroy] + [:show_past]
  )

  # ----- Herbaria: standard actions -------------------------------------------
  namespace :herbaria do
    resources :curator_requests, only: [:new, :create]
    resources :curators, only: [:create, :destroy], id: /\d+/
    resources :merges, only: [:create]
    resources :nexts, only: [:show], id: /\d+/
  end
  resources :herbaria, id: /\d+/
  # Herbaria: standard redirects of Herbarium legacy actions
  redirect_legacy_actions(
    old_controller: "herbarium", new_controller: "herbaria",
    actions: LEGACY_CRUD_ACTIONS - [:controller, :index, :show_past]
  )
  # Herbaria: non-standard redirects of legacy Herbarium actions
  # Rails routes currently accept only template tokens
  # rubocop:disable Style/FormatStringToken
  get("/herbarium/herbarium_search", to: redirect(path: "herbaria"))
  get("/herbarium/index", to: redirect(path: "herbaria"))
  get("/herbarium/list_herbaria", to: redirect(path: "herbaria?flavor=all"))
  get("/herbarium/request_to_be_curator/:id",
      to: redirect(path: "herbaria/curator_requests/new?id=%{id}"))

  # Herbaria: complicated redirects of legacy Herbarium actions
  # Actions needing two routes in order to successfully redirect
  #
  # The immediately following "match" and "get" combine to redirect
  # the legacy herbarium/delete_curator to the new herbaria/curators
  # The "match" redirects
  #   GET("/herbarium/delete_curator/nnn?user=uuu") and
  #   POST("/herbarium/delete_curator/nnn?user=uuu")
  # to
  #   GET("/herbaria/curators/nnn?user=uuu")
  # which would throw: No route matches [GET] "/herbaria/curators/nnnnn"
  # absent the following get
  match("/herbarium/delete_curator/:id",
        to: redirect(path: "/herbaria/curators/%{id}"),
        via: [:get, :post])
  get("/herbaria/curators/:id", to: "herbaria/curators#destroy", id: /\d+/)

  # The next post and get combine to redirect the legacy
  #   POST /herbarium/request_to_be_curator to
  #   POST herbaria/curator_requests#create
  post("/herbarium/request_to_be_curator/:id",
       to: redirect(path: "/herbaria/curator_requests?id=%{id}"))
  get("/herbaria/curator_requests",
      to: "herbaria/curator_requests#create", id: /\d+/)

  # The next post and get combine to redirect the legacy
  #   POST /herbarium/show_herbarium/:id to
  #   POST herbaria/curators#create
  post("/herbarium/show_herbarium", to: redirect(path: "herbaria/curators"))
  get("/herbaria/curators", to: "herbaria/curators#create", id: /\d+/)

  # Herbaria: broken redirects of legacy Herbarium actions
  get("/herbarium/next_herbarium/:id",
      to: redirect(path: "herbaria/%{id}?flow=next"))
  get("/herbarium/prev_herbarium/:id",
      to: redirect(path: "herbaria/%{id}?flow=prev"))
  get("/herbarium/merge_herbaria",
      to: redirect(path: "herbaria/merges#create"), that: /\d+/, this: /\d+/)

  # rubocop:enable Style/FormatStringToken

  # Herbaria: non-standard redirect
  # Must be the final route in order to avoid intercepting the above routes
  get("/herbarium", to: redirect(path: "herbaria?flavor=nonpersonal"))

  get "publications/:id/destroy" => "publications#destroy"
  resources :publications

  resources :contest_ballots, id: /\d+/
  resources :contest_entries, id: /\d+/

  # Short-hand notation for AJAX methods.
  # get "ajax/:action/:type/:id" => "ajax", constraints: { id: /\S.*/ }
  AJAX_ACTIONS.each do |action|
    get("ajax/#{action}/:type/:id",
        controller: "ajax", action: action, id: /\S.*/)
  end

  # Accept non-numeric ids for the /observer/lookup_xxx/id actions.
  LOOKUP_XXX_ID_ACTIONS.each do |action|
    get("observer/#{action}/:id",
        controller: "observer", action: action, id: /.*/)
  end

  # declare routes for the actions in the ACTIONS hash
  route_actions_hash

  # routes for actions that Rails automatically creates from view templates
  MO.themes.each { |scheme| get "theme/#{scheme}" }
end
