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
  include Phlex::Rails::Helpers::TurboStreamFrom
  # Rails text helpers used by Phlex views (article-list teasers,
  # other future preview/excerpt sites). Same stable-wrapper bucket
  # as `LinkTo` / `ButtonTo` above.
  include Phlex::Rails::Helpers::StripTags
  include Phlex::Rails::Helpers::Truncate
  include Phlex::Rails::Helpers::NumberWithPrecision
  include Phlex::TrustedHtml
  # `content_for(...)` and `content_for?(...)` — available everywhere
  # so chrome components, popup builders, etc. don't have to inherit
  # from Views::Base just for the stash/read pair.
  include Phlex::Rails::Helpers::ContentFor
  include Phlex::Rails::Helpers::DOMID
  # `rank_as_string`, `image_vote_as_*_string` — translation-key
  # shortcuts for enum-like model attributes.
  include Components::Localization
  # `viewer_aware_unique_format_name`, `viewer_aware_location_format`
  # — shared with ApplicationController (see app/classes/
  # viewer_aware_format.rb for why this isn't a register_value_helper
  # instead).
  include ViewerAwareFormat
  # `display_lat_lng`, `display_alt`, `place_name_and_coordinates`,
  # `format_coordinate` — see app/classes/coordinate_format.rb.
  include CoordinateFormat

  # Register custom value helpers (return values)
  register_value_helper :permission?
  register_value_helper :in_admin_mode?
  register_value_helper :reviewer?
  # The logged-in User (or nil). Reads off the controller's
  # before-filter-set `@user` ivar — request-scoped, no thread-
  # local. Views that need "the viewer" can call `current_user`
  # instead of taking a `prop :user, _Nilable(::User)`; views that
  # need a non-viewer subject User keep the prop. See
  # `ApplicationController::Authentication#current_user`.
  register_value_helper :current_user
  register_value_helper :url_for
  register_value_helper :add_q_param
  register_value_helper :q_param
  # The Query for "what the user is currently looking at" — pulled
  # from the controller's `@query` ivar, the URL's `q` param, or the
  # session's stored query_record (in that order, via
  # `ApplicationController::Queries#current_query`). Lets Phlex
  # views accept a typed `prop :query, ::Query` for validated input
  # AND fall back to "whatever query the session knows about" when
  # the prop is omitted, without having to thread `@query` through
  # every view-layer caller.
  register_value_helper :current_query
  # The non-beta `Language` list MO offers in the sidebar's language
  # picker (plus a couple of preferences / translators pages). Memoized
  # lazily by `ApplicationController::Internationalization#current_languages`
  # on first read — request-context, not action-specific. Same shape as
  # `current_user` / `current_query`.
  register_value_helper :current_languages
  register_value_helper :add_args_to_url
  register_value_helper :controller
  register_value_helper :controller_name
  register_value_helper :controller_path
  register_value_helper :action_name
  register_value_helper :params
  register_value_helper :request
  register_value_helper :session

  # Enable fragment caching
  def cache_store
    Rails.cache
  end

  # `add_args_to_url(url, new_args)` — take an arbitrary URL and
  # change its parameters. Returns a new URL string. `new_args` is a
  # Hash; `nil` values delete the matching params.
  def add_args_to_url(url, new_args)
    return url unless url.valid_encoding?

    new_args = new_args.clone
    addr, parms = url.split("?")
    args = parms ? Rack::Utils.parse_nested_query(parms) : {}
    addr = consume_id_into_path!(addr, new_args)
    merge_url_args!(args, new_args)

    args.empty? ? addr : "#{addr}?#{args.to_query}"
  end

  # `/xxx/id` special case — if `addr` ends in `/<digits>` and
  # `new_args[:id]` is set, replace the trailing id segment and
  # delete `:id`/`"id"` from `new_args` so it doesn't ALSO end up
  # as a query param.
  def consume_id_into_path!(addr, new_args)
    return addr unless %r{/(\d+)$}.match?(addr)

    new_id = new_args[:id] || new_args["id"]
    addr = addr.sub(/\d+$/, new_id.to_s) if new_id
    new_args.delete(:id)
    new_args.delete("id")
    addr
  end

  # Stringify-merge `new_args` into `args`; nil values delete the
  # matching key. AR records get their `id` to keep query strings short.
  def merge_url_args!(args, new_args)
    new_args.each_key do |var|
      val = new_args[var]
      if val.nil?
        args.delete(var.to_s)
      else
        args[var.to_s] = val.is_a?(ActiveRecord::Base) ? val.id.to_s : val.to_s
      end
    end
  end

  def nbsp
    trusted_html("&nbsp;")
  end

  # ViewerAwareFormat's default `user` arg.
  def default_viewer
    current_user
  end

  def before_template
    comment { "Before #{self.class.name}" } if Rails.env.development?
    super
  end
end
