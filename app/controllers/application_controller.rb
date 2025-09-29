# frozen_string_literal: true

#
#  = Application Controller Base Class
#
#  This is the base class for all the application's controllers.  It contains
#  all the important application-wide filters and lots of helper methods.
#  Anything that appears here is available to every controller and view.
#
#  == Methods
#  *NOTE*: Methods in parentheses are "private" helpers; you are encouraged to
#  use the public ones instead.
#
#  ==== Memory usage
#  extra_gc::               (filter: calls <tt>ObjectSpace.garbage_collect</tt>)
#
#  ==== Other stuff
#  observation_matrix_box_image_includes:: Hash of includes for eager-loading
#  name_flash_for_project::      Flash message for adding obs to projects
#  default_thumbnail_size::      Default thumbnail size: :thumbnail or :small.
#  default_thumbnail_size_set::  Change default thumbnail size for current user.
#  rubric::                      Label for what the controller deals with
#  update_view_stats::           Called after each show_object request.
#  calc_layout_params::          Gather User's list layout preferences.
#  catch_errors_and_log_request_stats::
#                                (filter: catches errors for integration tests)
#
class ApplicationController < ActionController::Base
  include LoginSystem
  include Authentication
  include Internationalization
  include FlashNotices
  include NameValidation
  include Queries
  include Indexes

  # Allow folder organization in the app/views folder
  append_view_path Rails.root.join("app/views/controllers")

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  around_action :catch_errors_and_log_request_stats
  before_action :kick_out_excessive_traffic
  before_action :kick_out_robots
  before_action :verify_authenticity_token
  before_action :fix_bad_domains
  before_action :autologin
  before_action :set_locale
  before_action :set_timezone
  before_action :track_translations

  # Make show_name_helper available to nested partials
  helper :names

  # Disable most filters to streamline some actions, e.g., API.
  def self.disable_filters
    skip_before_action(:verify_authenticity_token)
    skip_before_action(:fix_bad_domains)
    skip_before_action(:autologin)
    skip_before_action(:set_timezone)
    skip_before_action(:track_translations)
    before_action { User.current = nil }
  end

  # Disables Bullet tester for one action. Use this in your controller:
  #   around_action :skip_bullet, if: -> { defined?(Bullet) }, only: [ ... ]
  def skip_bullet
    # puts("skip_bullet: OFF\n")
    old_value = Bullet.n_plus_one_query_enable?
    Bullet.n_plus_one_query_enable = false
    yield
  ensure
    # puts("skip_bullet: ON\n")
    Bullet.n_plus_one_query_enable = old_value
  end

  # @view can be used by classes to access view specific features like render
  # huge context though! Don't use if you don't need it
  # def create_view_instance_variable
  #   @view = view_context
  # end

  # Kick out agents responsible for excessive traffic.
  def kick_out_excessive_traffic
    return true if is_cool?

    logger.warn("BLOCKED #{request.remote_ip}")
    email = MO.webmaster_email_address
    msg = :kick_out_message.l(ip: request.remote_ip, email: email)
    render(plain: msg, status: :too_many_requests, layout: false)
    false
  end

  def is_cool?
    return true unless IpStats.blocked?(request.remote_ip)
    return true if params[:controller] == "account" &&
                   params[:action] == "login"

    session[:user_id].present?
  end

  # Physically eject robots unless they're looking at accepted pages.
  def kick_out_robots
    return true if params[:controller].start_with?("api")
    return true if params[:controller] == "account/login"
    return true unless browser.bot?
    return true if Robots.authorized?(browser.ua) &&
                   Robots.action_allowed?(
                     controller: params[:controller],
                     action: params[:action]
                   )

    render(plain: "Robots are not allowed on this page.",
           status: :forbidden,
           layout: false)
    false
  end

  # Enable this to test other layouts...
  layout :choose_layout
  def choose_layout
    change = params[:user_theme].to_s
    change_theme_to(change) if change.present?
    layout = session[:layout].to_s
    layout = "application" if layout.blank?
    layout
  end

  def change_theme_to(change)
    if MO.themes.member?(change)
      if @user
        @user.theme = change
        @user.save
      else
        session[:theme] = change
      end
    else
      session[:layout] = change
    end
  end

  # Catch errors for integration tests, and report stats re completed request.
  def catch_errors_and_log_request_stats
    clear_user_globals
    stats = request_stats
    yield
    IpStats.log_stats(stats, @user&.id)
    logger.warn(request_stats_log_message(stats))
  rescue StandardError => e
    raise(@error = e)
  end

  def request_stats
    {
      time: Time.current,
      controller: params[:controller],
      action: params[:action],
      api_key: params[:api_key],
      robot: browser.bot? ? "robot" : "user",
      ip: request.try(&:remote_ip),
      url: request.try(&:url),
      ua: browser.try(&:ua)
    }
  end

  def request_stats_log_message(stats)
    "TIME: #{Time.current - stats[:time]} #{status} " \
    "#{stats[:controller]} #{stats[:action]} " \
    "#{stats[:robot]} #{stats[:ip]}\t#{stats[:url]}\t#{stats[:ua]}"
  end

  private :request_stats, :request_stats_log_message

  # Keep track of localization strings so users can edit them (sort of) in situ.
  def track_translations
    @language = Language.find_by(locale: I18n.locale)
    if @user && @language &&
       (!@language.official || reviewer?)
      Language.track_usage(flash[:tags_on_last_page])
    else
      Language.ignore_usage
    end
  end

  # Redirect from www.mo.org to mo.org.
  #
  # This would be much easier to check if HTTP_HOST != MO.domain, but if this
  # ever were to break we'd get into an infinite loop too easily that way.
  # I think this is a lot safer.  MO.bad_domains would be something like:
  #
  #   MO.bad_domains = [
  #     'www.mushroomobserver.org',
  #     'mushroomobserver.com',
  #   ]
  #
  # The importance of this is that browsers are storing different cookies
  # for the different domains, even though they are all getting routed here.
  # This is particularly problematic when a fully-specified link in, say,
  # a comment's body is different.  This results in you having to re-login
  # when you click on these embedded links.
  #
  def fix_bad_domains
    if (request.method == "GET") &&
       MO.bad_domains.include?(request.env["HTTP_HOST"])
      redirect_to("#{MO.http_domain}#{request.fullpath}")
    end
  end

  # public ##########

  ##############################################################################
  #
  #  :section: Memory usage.
  #
  ##############################################################################

  def extra_gc
    ObjectSpace.garbage_collect
  end

  ##############################################################################
  #
  #  :section: Other stuff
  #
  ##############################################################################

  def observation_matrix_box_image_includes
    { thumb_image: [:image_votes, :license, :projects, :user] }.freeze
    # for matrix_box_carousels:
    # { images: [:image_votes, :license, :projects, :user] }.freeze
  end

  def name_flash_for_project(name, project)
    return unless name && project

    count = project.count_collections(name)
    if count == 1
      flash_warning(:project_first_collection.t(name: name.text_name,
                                                project: project.title))
    else
      flash_notice(:project_count_collections.t(count: count,
                                                name: name.text_name,
                                                project: project.title))
    end
  end

  # Tell an object that someone has looked at it (unless a robot made the
  # request).
  def update_view_stats(object)
    return unless object.respond_to?(:update_view_stats) && !browser.bot?

    object.update_view_stats(@user)
  end

  # Default image size to use for thumbnails: either :thumbnail or :small.
  # Looks at both the user's pref (if logged in) or the session (if not logged
  # in), else reverts to small. *NOTE*: This method is available to views.
  def default_thumbnail_size
    if @user
      @user.thumbnail_size
    else
      session[:thumbnail_size]
    end || "thumbnail"
  end
  helper_method :default_thumbnail_size

  def default_thumbnail_size_set(val)
    if @user && @user.thumbnail_size != val
      @user.thumbnail_size = val
      @user.save_without_our_callbacks
    else
      session[:thumbnail_size] = val
    end
  end

  # "rubric"
  # The name of the "application domain" of the present controller. In human
  # terms, it's a label for "what we're dealing with on this page, generally."
  # Usually that would be the same as the controller_name, like
  # "Observations" or "Account". But in a nested controller like
  # "Locations::Descriptions::DefaultsController" though, what we want is just
  # the "Locations" part, so we need to parse the class.module_parent.
  #
  # NOTE: The rubric can of course be overridden in each controller.
  #
  # Returns a translation string.
  #
  def rubric
    # Levels of nesting. parent_module is one level.
    if (parent = parent_controller_module)
      return parent.underscore.upcase.to_sym.t
    end

    controller_name.upcase.to_sym.t
  end
  helper_method :rubric

  # Returns the CamelCase parent module name, e.g. "Locations" for
  # "Locations::MapsController"
  # gotcha - `Object` is the module_parent of a top-level controller!
  def parent_controller_module
    return unless (parent_module = self.class.module_parent).present? &&
                  parent_module != Object

    if (grandma_module = parent_module.to_s.rpartition("::").first).present?
      return grandma_module
    end

    parent_module.to_s
  end
  helper_method :parent_controller_module

  def calc_layout_params
    count = @user&.layout_count || MO.default_layout_count
    count = 1 if count < 1
    { "count" => count }
  end
  helper_method :calc_layout_params

  # NOTE: SpeciesList show pages cannot nav prev/next within a project without
  # having the project param stored inside the query record, q.
  def set_project_ivar
    # NOTE: Query param projects is always an array of ids.
    query_projects = params.dig(:q, :projects) || []
    # If more than one project, it's none. Only want single-project associations
    query_project = query_projects.size > 1 ? nil : query_projects.first
    project_id = params[:project] || query_project
    # At this point, we still might not have one. That's fine - just return nil.
    @project = Project.safe_find(project_id)
  end

  def render_xml(args)
    request.format = "xml"
    respond_to do |format|
      format.xml { render(args) }
    end
  end

  def load_for_show_observation_or_goto_index(id)
    Observation.show_includes.find_by(id: id) ||
      flash_error_and_goto_index(Observation, id)
  end

  def query_images_to_reuse(all_users, user)
    return create_query(:Image, order_by: :updated_at) if all_users || !user

    create_query(:Image, by_users: user, order_by: :updated_at)
  end
  helper_method :query_images_to_reuse

  ##############################################################################

  private

  # defined here because used by both images_controller and
  # observations_controller
  def permitted_image_args
    [:copyright_holder, :image, :license_id, :notes, :original_name, :when]
  end

  def upload_image(upload, copyright_holder, license_id, copyright_year)
    image = Image.new(
      image: upload,
      user: @user,
      when: Date.parse("#{copyright_year}0101"),
      copyright_holder: copyright_holder,
      license: License.safe_find(license_id)
    )
    deal_with_upload_errors_or_success(image)
  end

  def deal_with_upload_errors_or_success(image)
    if !image.save
      flash_object_errors(image)
    elsif !image.process_image
      name = image.original_name
      name = "???" if name.empty?
      flash_error(:runtime_profile_invalid_image.t(name: name))
      flash_object_errors(image)
    else
      name = image.original_name
      name = "##{image.id}" if name.empty?
      flash_notice(:runtime_profile_uploaded_image.t(name: name))
      return image
    end
    nil
  end
end
