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
  articles: {
    # create_article: {}, # aliased only
    # destroy_article: {}, # aliased only
    # edit_article: {}, # aliased only
    index_article: {},
    # list_articles: {}, # aliased only
    # show_article: {}, # aliased only
    # resources
    # create: {},
    # destroy: {},
    # edit: {},
    # index: {},
    # new: {},
    # show: {},
    # update: {}
  },
  authors: {
    review_authors: {}
  },
  collection_numbers: {
    collection_number_search: {},
    # create_collection_number: {}, # aliased only
    # destroy_collection_number: {}, # aliased only
    # edit_collection_number: {}, # aliased only
    index_collection_number: {},
    # list_collection_numbers: {}, # aliased only
    # next_collection_number: {}, # aliased only
    observation_index: {},
    # prev_collection_number: {}, # aliased only
    remove_observation: {},
    # show_collection_number: {}, # aliased only
    show_next: {},
    show_prev: {}
    # resources
    # create: {},
    # destroy: {},
    # edit: {},
    # index: {},
    # new: {},
    # show: {},
    # update: {}
  },
  comments: {
    # add_comment: {}, # aliased only
    comment_search: {},
    # destroy_comment: {}, # aliased only
    # edit_comment: {}, # aliased only
    index_comment: {},
    # list_comments: {}, # aliased only
    # next_comment: {}, # aliased only
    # prev_comment: {}, # aliased only
    # show_comment: {}, # aliased only
    show_comments_by_user: {},
    show_comments_for_target: {},
    show_comments_for_user: {},
    show_next: {},
    show_prev: {}
    # resources
    # create: {},
    # destroy: {},
    # edit: {},
    # index: {},
    # new: {},
    # show: {},
    # update: {}
  },
  email: {
    email_features: {},
    email_merge_request: {},
    ask_observation_question: {},
    ask_webmaster_question: {},
    ask_user_question: {},
    commercial_inquiry: {},
    email_question: {}
  },
  glossary: {
    # create_glossary_term: {}, # aliased only
    # edit_glossary_term: {}, # aliased only
    # show_glossary_term: {}, # aliased only
    show_past_glossary_term: {}
    # resources
    # create: {},
    # destroy: {},
    # edit: {},
    # index: {},
    # new: {},
    # show: {},
    # update: {}
  },
  herbaria: {
    # create_herbarium: {}, # aliased only
    delete_curator: {},
    # destroy_herbarium: {}, # aliased only
    # edit_herbarium: {}, # aliased only
    herbarium_search: {},
    index_herbarium: {},
    # list_herbaria: {}, # aliased only
    merge_herbaria: {},
    # next_herbarium: {}, # aliased only
    # prev_herbarium: {}, # aliased only
    request_to_be_curator: {},
    # show_herbarium: {}, # aliased only
    show_next: {},
    show_prev: {}
    # resources
    # create: {},
    # destroy: {},
    # edit: {},
    # index: {},
    # new: {},
    # show: {},
    # update: {}
  },
  herbarium_records: {
    # create_herbarium_record: {}, # aliased only
    # destroy_herbarium_record: {}, # aliased only
    # edit_herbarium_record: {}, # aliased only
    herbarium_index: {},
    herbarium_record_search: {},
    index_herbarium_record: {},
    # list_herbarium_records: {}, # aliased only
    # next_herbarium_record: {}, # aliased only
    observation_index: {},
    # prev_herbarium_record: {}, # aliased only
    remove_observation: {},
    # show_herbarium_record: {}, # aliased only
    show_next: {},
    show_prev: {}
    # resources
    # create: {},
    # destroy: {},
    # edit: {},
    # index: {},
    # new: {},
    # show: {},
    # update: {}
  },
  images: {
    # add_image: {}, # aliased only
    advanced_search: {},
    bulk_filename_purge: {},
    bulk_vote_anonymity_updater: {},
    cast_vote: {},
    # destroy_image: {}, # aliased only
    # edit_image: {}, # aliased only
    image_search: {},
    images_by_user: {},
    images_for_project: {},
    index_image: {},
    license_updater: {},
    # list_images: {}, # aliased only
    # next_image: {}, # aliased only
    # prev_image: {}, # aliased only
    remove_images: {},
    remove_images_for_glossary_term: {},
    reuse_image: {},
    reuse_image_for_glossary_term: {},
    # show_image: {}, # aliased only
    show_original: {},
    transform_image: {},
    show_next: {},
    show_prev: {}
    # resources
    # create: {},
    # destroy: {},
    # edit: {},
    # index: {},
    # new: {},
    # show: {},
    # update: {}
  },
  info: {
    how_to_help: {},
    how_to_use: {},
    intro: {},
    show_site_stats: {},
    search_bar_help: {},
    textile: {}, # aliased only
    textile_sandbox: {},
    translators_note: {}
  },
  interests: {
    destroy_notification: {},
    list_interests: {},
    set_interest: {}
  },
  locations: {
    add_to_location: {},
    adjust_permissions: {},
    advanced_search: {},
    # create_location: {}, # aliased only
    # destroy_location: {}, # aliased only
    # edit_location: {}, # aliased only
    help: {},
    index_location: {},
    list_by_country: {},
    list_countries: {},
    # list_locations: {}, # aliased only
    list_merge_options: {},
    location_search: {},
    locations_by_editor: {},
    locations_by_user: {},
    map_locations: {},
    # next_location: {}, # aliased only
    # prev_location: {}, # aliased only
    reverse_name_order: {},
    # show_location: {}, # aliased only
    show_past_location: {},
    show_next: {},
    show_prev: {}
    # resources
    # create: {},
    # destroy: {},
    # edit: {},
    # index: {},
    # new: {},
    # show: {},
    # update: {}
  },
  location_descriptions: {
    # create_location_description: {}, # aliased only
    # destroy_location_description: {}, # aliased only
    # edit_location_description: {}, # aliased only
    index_location_description: {},
    # list_location_descriptions: {}, # aliased only
    location_descriptions_by_author: {},
    location_descriptions_by_editor: {},
    make_description_default: {},
    merge_descriptions: {}, # ?
    # next_location_description: {}, # aliased only
    # prev_location_description: {}, # aliased only
    publish_description: {}, # ?
    # show_location_description: {}, # aliased only
    show_past_location_description: {},
    show_next: {},
    show_prev: {}
    # resources
    # create: {},
    # destroy: {},
    # edit: {},
    # index: {},
    # new: {},
    # show: {},
    # update: {}
  },
  lookup: {
    lookup_accepted_name: {},
    lookup_comment: {},
    lookup_image: {},
    lookup_location: {},
    lookup_name: {},
    lookup_observation: {},
    lookup_project: {},
    lookup_species_list: {},
    lookup_user: {}
  },
  names: {
    adjust_permissions: {},
    advanced_search: {},
    approve_name: {},
    authored_names: {},
    bulk_name_edit: {},
    change_synonyms: {},
    # create_name: {}, # aliased only
    deprecate_name: {},
    edit_classification: {},
    edit_lifeform: {},
    # edit_name: {}, # aliased only
    email_tracking: {},
    eol: {},
    eol_expanded_review: {},
    eol_preview: {},
    index_name: {},
    inherit_classification: {},
    # list_names: {}, # aliased only
    make_description_default: {},
    map: {},
    merge_descriptions: {},
    name_search: {},
    names_by_author: {},
    names_by_editor: {},
    names_by_user: {},
    needed_descriptions: {},
    # next_name: {}, # aliased only
    observation_index: {},
    # prev_name: {}, # aliased only
    propagate_classification: {},
    propagate_lifeform: {},
    publish_description: {},
    refresh_classification: {},
    set_review_status: {},
    # show_name: {}, # aliased only
    show_past_name: {},
    test_index: {},
    show_next: {},
    show_prev: {}
    # resources
    # create: {},
    # destroy: {},
    # edit: {},
    # index: {},
    # new: {},
    # show: {},
    # update: {}
  },
  name_descriptions: {
    # create_name_description: {}, # aliased only
    # destroy_name_description: {}, # aliased only
    # edit_name_description: {}, # aliased only
    index_name_description: {},
    # list_name_descriptions: {}, # aliased only
    name_descriptions_by_author: {},
    name_descriptions_by_editor: {},
    # next_name_description: {}, # aliased only
    # prev_name_description: {}, # aliased only
    # show_name_description: {}, # aliased only
    show_past_name_description: {},
    show_next: {},
    show_prev: {}
    # resources
    # create: {},
    # destroy: {},
    # edit: {},
    # index: {},
    # new: {},
    # show: {},
    # update: {}
  },
  # namings: {
  #   create_post: {}, # alias for create
  #   edit_post: {}, # alias for update
  #   # resources
  #   create: {}, # action has changed, now "new"
  #   destroy: {},
  #   edit: {},
  #   new: {},
  #   update: {}
  # },
  # notifications: {
  #   show_notifications: {}, # aliased only
  #   show: {}
  # },
  observations: {
    # create_observation: {}, # aliased only
    # destroy_observation: {}, # aliased only
    download_observations: {},
    # edit_observation: {}, # aliased only
    hide_thumbnail_map: {},
    index_observation: {},
    # list_observations: {}, # aliased only
    map_observation: {},
    map_observations: {},
    # next_observation: {}, # aliased only
    observation_search: {},
    observations_at_location: {},
    observations_at_where: {},
    observations_by_name: {},
    observations_by_user: {},
    observations_for_project: {},
    observations_of_name: {},
    # prev_observation: {}, # aliased only
    print_labels: {},
    recalc: {},
    search_bar_help: {},
    show_location_observations: {},
    # show_obs: {}, # aliased only
    # show_observation: {}, # aliased only
    suggestions: {},
    update_whitelisted_observation_attributes: {},
    # other
    set_export_status: {},
    test_flash_redirection: {},
    turn_javascript_nil: {},
    turn_javascript_off: {},
    turn_javascript_on: {},
    w3c_tests: {},
    show_next: {},
    show_prev: {}
    # resources
    # create: {},
    # destroy: {},
    # edit: {},
    # index: {},
    # new: {},
    # show: {},
    # update: {}
  },
  # pivotal: {
    # index: {}
  # },
  projects: {
    add_members: {},
    # add_project: {}, # aliased only
    admin_request: {},
    change_member_status: {},
    # destroy_project: {}, # aliased only
    # edit_project: {}, # aliased only
    index_project: {},
    # list_projects: {}, # aliased only
    # next_project: {}, # aliased only
    # prev_project: {}, # aliased only
    project_search: {},
    # show_project: {}, # aliased only
    show_next: {},
    show_prev: {}
    # resources
    # create: {},
    # destroy: {},
    # edit: {},
    # index: {},
    # new: {},
    # show: {},
    # update: {}
  },
  # publications: {
    # resources
    # create: {},
    # destroy: {},
    # edit: {},
    # index: {},
    # new: {},
    # show: {},
    # update: {}
  # },
  rss_logs: {
    change_banner: {},
    index_rss_log: {},
    # list_rss_logs: {}, # aliased only
    # next_rss_log: {}, # aliased only
    # prev_rss_log: {}, # aliased only
    rss: {},
    # show_rss_log: {}, # aliased only
    show_next: {},
    show_prev: {}
    # resources
    # index: {},
    # show: {}
  },
  search: {
    advanced_search: {},
    advanced_search_form: {},
    pattern_search: {},
    site_google_search: {}
  },
  sequences: {
    # create_sequence: {}, # aliased only
    # destroy_sequence: {}, # aliased only
    # edit_sequence: {}, # aliased only
    index_sequence: {},
    # list_sequences: {}, # aliased only
    # next_sequence: {}, # aliased only
    observation_index: {},
    # prev_sequence: {}, # aliased only
    sequence_search: {},
    # show_sequence: {}, # aliased only
    show_next: {},
    show_prev: {}
    # resources
    # create: {},
    # destroy: {},
    # edit: {},
    # index: {},
    # new: {},
    # show: {},
    # update: {}
  },
  species_lists: {
    add_observation_to_species_list: {},
    add_remove_observations: {},
    bulk_editor: {},
    # create_species_list: {}, # aliased only
    # destroy_species_list: {}, # aliased only
    # edit_species_list: {}, # aliased only
    index_species_list: {},
    # list_species_lists: {}, # aliased only
    make_report: {},
    manage_projects: {},
    manage_species_lists: {},
    name_lister: {},
    # next_species_list: {}, # aliased only
    post_add_remove_observations: {},
    # prev_species_list: {}, # aliased only
    print_labels: {},
    remove_observation_from_species_list: {},
    # show_species_list: {}, # aliased only
    species_list_search: {},
    species_lists_by_title: {},
    species_lists_by_user: {},
    species_lists_for_project: {},
    upload_species_list: {},
    show_next: {},
    show_prev: {}
    # resources
    # create: {},
    # destroy: {},
    # edit: {},
    # index: {},
    # new: {},
    # show: {},
    # update: {}
  },
  support: {
    confirm: {},
    create_donation: {},
    donate: {},
    donors: {},
    governance: {},
    letter: {},
    letter_to_community: {},
    review_donations: {},
    thanks: {},
    wrapup_2011: {},
    wrapup_2012: {}
  },
  themes: {
    color_themes: {}
  },
  translations: {
    edit_translations: {},
    edit_translations_ajax_get: {},
    edit_translations_ajax_post: {}
  },
  users: {
    change_user_bonuses: {},
    checklist: {},
    index_user: {},
    ilist_users: {},
    # list_users: {}, # aliased only
    # next_user: {}, # aliased only
    # prev_user: {}, # aliased only
    # show_user: {}, # aliased only
    users_by_contribution: {},
    users_by_name: {},
    user_search: {},
    show_next: {},
    show_prev: {}
    # resources
    # index: {},
    # show: {}
  },
  votes: {
    cast_vote: {},
    cast_votes: {},
    refresh_vote_cache: {},
    # show_votes: {}, # aliased only
    show: {}
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

MushroomObserver::Application.routes.draw do

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

  # Logged in - Default page is /rss_logs#index.
  # https://stackoverflow.com/questions/6998612/rails-3-best-way-to-have-two-different-home-pages-based-on-login-status
  # constraints lambda { |req| !req.session[:user_id].blank? } do
    # root :to => "rss_logs#index"
  # end

  # Not logged in - Default page is /observations#index.
  root :to => "observations#index"

  resources :articles, :collection_numbers, :comments, :glossary, :herbaria,
  :herbarium_records, :images, :namings, :observations, :projects,
  :publications, :sequences, :species_lists

  # http://jeromedalbert.com/how-dhh-organizes-his-rails-controllers/
  resources :names do
    resources :descriptions, module: :names
  end

  resources :locations do
    resources :descriptions, module: :locations
  end

  resources :notifications, only: [:show]

  resources :pivotal, only: [:index]

  resources :rss_logs, only: [:index, :show]

  resources :users, only: [:index, :show]

  get "policy/privacy"

  # Route /123 to /observations/show_observation/123.
  get ":id" => "observations#show", id: /\d+/
  # get "observations/:id" => "observations#show", id: /\d+/

  # Short-hand notation for AJAX methods.
  # get "ajax/:action/:type/:id" => "ajax", constraints: { id: /\S.*/ }
  AJAX_ACTIONS.each do |action|
    get(
      "ajax/#{action}/:type/:id",
      controller: :ajax,
      action: action,
      id: /\S.*/
    )
  end

  # Accept non-numeric ids for the /observer/lookup_xxx/id actions.
  LOOKUP_XXX_ID_ACTIONS.each do |action|
    get(
      "observations/#{action}/:id",
      controller: :observations,
      action: action,
      id: /.*/
    )
  end

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

  # routes for actions that Rails automatically creates from view templates
  MO.themes.each { |scheme| get "theme/#{scheme}" }
end
