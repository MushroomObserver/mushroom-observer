# frozen_string_literal: true

# Main application sidebar with navigation and user controls.
# Rendered once in the application layout. Also the namespace for
# the sidebar's nested Phlex partials (`Admin`, `Login`, `Section`,
# `User`, `Languages`, `ContextNav`) — autoloaded from
# `app/views/layouts/sidebar/*.rb`.
#
# @example Basic usage in layout
#   <%= render(Views::Layouts::Sidebar.new(
#     user: @user,
#     browser: browser,
#     request: request
#   )) %>
class Views::Layouts::Sidebar < Views::Base
  # The Bootstrap modifier classes the nested partials (`Admin`,
  # `Login`, `Section`, `User`, etc.) read via the `classes:` prop
  # and apply on top of `list-group-item` via
  # `Components::ListGroup::Item` / `LinkItem` — neither key
  # includes the `list-group-item` prefix itself, since both
  # components compose it automatically. `Sidebar::ContextNav`
  # reuses the same set for its mobile rendering into the offcanvas
  # sidebar.
  CSS_CLASSES = {
    heading: "disabled font-weight-bold",
    admin: "list-group-item-danger indent",
    indent: "indent",
    mobile_only: "visible-xs"
  }.freeze

  prop :user, _Nilable(::User), default: nil
  # Duck-typed: only `#bot?` is read (in `_logo_link_path` and
  # `_user_sections`). Accepts a real `Browser::Base` or any stub
  # that responds to `#bot?`.
  prop :browser, _Interface(:bot?)
  # Duck-typed: only `#url` is read via `reload_with_args` (inherited
  # from `Views::Base`). Accepts an `ActionDispatch::Request` or any
  # stub with `#url`.
  prop :request, _Interface(:url)
  prop :languages, _Array(Language)

  def view_template
    Column(element: :nav, id: "sidebar", xs: 8, sm: 2,
           class: "sidebar-offcanvas hidden-print") do
      comment { "SIDEBAR LOGO AND NAVIGATION" }
      div(id: "navigation") do
        render_logo
        Navbar(variant: :inverse, element: :div, class: "sidebar-nav",
               data_controller: "nav-active") do
          # `w-100`: `.navbar.navbar-flex`'s BS4 bridge rule makes this
          # element's parent `display: flex`; without an explicit
          # width this direct child would shrink to content size
          # instead of staying full width.
          div(class: "list-group w-100") do
            render_top_section
            render_context_nav_mobile if @user
            render_user_sections
            render_info_sections
          end
        end
      end
      comment { "/SIDEBAR LOGO AND NAVIGATION" }
    end
  end

  private

  def classes
    CSS_CLASSES
  end

  def render_logo
    a(id: "logo_link", href: logo_href) do
      img(
        class: "logo-trim img-responsive py-10px",
        alt: "Mushroom Observer Logo",
        src: "/logo-trim.png"
      )
    end
    comment { "#logo_link" }
  end

  def logo_href
    @browser.bot? ? "/sitemap/index.html" : "/"
  end

  def render_top_section
    # This cache depends on user status and locale
    cache([I18n.locale, user_status_string(@user), "login"]) do
      if in_admin_mode?
        render(Views::Layouts::Sidebar::Admin.new(
                 heading_key: :app_admin,
                 tabs: Tab::Sidebar::AdminActions.new.map(&:to_a),
                 classes: classes
               ))
      elsif @user.nil?
        render(Views::Layouts::Sidebar::Login.new(
                 heading_key: :app_account,
                 tabs: Tab::Sidebar::LoginActions.new.map(&:to_a),
                 classes: classes
               ))
      end
    end
  end

  def render_context_nav_mobile
    # Output any content_for :context_nav_mobile
    context_nav = content_for(:context_nav_mobile)
    trusted_html(context_nav) if context_nav.present?
  end

  def render_user_sections
    # If caching obs/spl, this should be keyed for both User and QueryRecord
    # (i.e. cache invalidated if query record updated, or new ID).
    # cache([@user, current_query_record]) do
    if @user
      render(Views::Layouts::Sidebar::User.new(
               user: @user,
               classes: classes
             ))
    end

    render(Views::Layouts::Sidebar::Section.new(
             heading_key: :app_observations_left,
             tabs: Tab::Sidebar::ObservationsActions.new(
               user: @user
             ).map(&:to_a),
             classes: classes
           ))

    return unless @user

    render(Views::Layouts::Sidebar::Section.new(
             heading_key: :app_species_list,
             tabs: Tab::Sidebar::SpeciesListsActions.new(
               user: @user
             ).map(&:to_a),
             classes: classes
           ))

    # end
  end

  def render_info_sections
    # This cache depends on user status and locale
    cache([I18n.locale, user_status_string(@user), "links"]) do
      render_section(:app_latest, latest_tabs)
      render_section(:INDEXES, indexes_tabs) if @user
      render_section(:app_more, info_tabs)
      render_languages_section
    end
  end

  def render_section(heading_key, tabs)
    render(Views::Layouts::Sidebar::Section.new(
             heading_key: heading_key, tabs: tabs, classes: classes
           ))
  end

  def latest_tabs
    Tab::Sidebar::LatestActions.new(user: @user).map(&:to_a)
  end

  def indexes_tabs
    Tab::Sidebar::IndexesActions.new.map(&:to_a)
  end

  def info_tabs
    Tab::Sidebar::InfoActions.new.map(&:to_a)
  end

  def render_languages_section
    return if @browser.bot?

    render(Views::Layouts::Sidebar::Languages.new(
             browser: @browser,
             request: @request,
             languages: @languages
           ))
  end

  def user_status_string(user = nil)
    if in_admin_mode?
      "admin_mode"
    elsif @browser.bot?
      "robot"
    elsif !user.nil?
      "user"
    else
      "guest"
    end
  end
end
