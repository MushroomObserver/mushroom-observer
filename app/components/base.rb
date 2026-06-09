# frozen_string_literal: true

class Components::Base < Phlex::HTML
  extend Literal::Properties

  # Include any helpers you want to be available across all components
  include Phlex::Rails::Helpers::Routes
  include Phlex::Rails::Helpers::AssetPath
  include Phlex::Rails::Helpers::LinkTo
  include Phlex::Rails::Helpers::ButtonTo
  include Phlex::Rails::Helpers::ClassNames
  include Phlex::Rails::Helpers::TurboFrameTag
  include Components::TrustedHtml
  # `content_for(...)` and `content_for?(...)` — available everywhere
  # so chrome components, popup builders, etc. don't have to inherit
  # from Views::Base just for the stash/read pair.
  include Phlex::Rails::Helpers::ContentFor

  # Register custom value helpers (return values)
  register_value_helper :permission?
  register_value_helper :in_admin_mode?
  # The logged-in User (or nil). Reads off the controller's
  # before-filter-set `@user` ivar — request-scoped, no thread-
  # local. Views that need "the viewer" can call `current_user`
  # instead of taking a `prop :user, _Nilable(::User)`; views that
  # need a non-viewer subject User keep the prop. See
  # `ApplicationController::Authentication#current_user`.
  register_value_helper :current_user
  register_value_helper :url_for
  register_value_helper :image_vote_as_short_string
  register_value_helper :image_vote_as_help_string
  register_value_helper :sequence_archive_options
  register_value_helper :add_q_param
  register_value_helper :q_param
  # The Query for "what the user is currently looking at" — pulled
  # from the controller's `@query` ivar, the URL's `q` param, or the
  # session's stored query_record (in that order, via
  # `ApplicationController::Queries#current_query`). Lets Phlex
  # views accept a typed `prop :query, ::Query` for validated input
  # AND fall back to "whatever query the session knows about" when
  # the prop is omitted, without having to thread `@query` through
  # every chrome-y caller.
  register_value_helper :current_query
  register_value_helper :add_args_to_url
  register_value_helper :controller
  register_value_helper :controller_name
  register_value_helper :controller_path
  register_value_helper :action_name
  register_value_helper :params

  # Enable fragment caching
  def cache_store
    Rails.cache
  end

  def before_template
    comment { "Before #{self.class.name}" } if Rails.env.development?
    super
  end
end
