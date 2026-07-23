# frozen_string_literal: true

# The top-of-page navbar. Composes:
#
#   - the left side (mobile nav-toggle button, the page title /
#     "rubric", and the "+ Add" create-button)
#   - the right side (search-bar toggle, QR-scanner link, the
#     `:context_nav` content_for hook for the Actions dropdown,
#     and either `Views::Layouts::TopNav::UserNav` or
#     `Views::Layouts::TopNav::Login` depending on
#     `@user.nil?`)
#   - the collapsible search-bar row
#
# Helpers from `Header::TogglesHelper` (`left_nav_toggle`,
# `search_nav_toggle`) and `Header::RubricHelper` (`nav_rubric`,
# `nav_create`, `nav_scan_qr_code` + their private helpers) are
# inlined as private methods on this class — those helpers had no
# other callers, so the helper modules are deleted in the same PR.
class Views::Layouts::TopNav < Views::Base
  # `content_for?` isn't auto-registered on `Views::Base` (only
  # the value-helper form of `content_for` is). The right-side
  # `<ul>` needs `content_for?(:context_nav)` to decide whether
  # to include the dropdown the page populated.
  include Phlex::Rails::Helpers::ContentFor

  prop :user, _Nilable(::User), default: nil
  prop :query, _Nilable(::Query), default: nil

  # Controllers / actions where the search-help dropdown is available
  SEARCH_HELP_TYPES = [:names, :observations, :locations].freeze
  SEARCH_FORM_TYPES = [
    :names, :observations, :locations,
    :projects, :herbaria, :species_lists
  ].freeze

  # Container classes shared by the top-nav row and the search-nav
  # row. `w-100` is load-bearing since #top_nav is now `display: flex`
  # (mo/_top_nav.scss's BS3->BS4 bridge rule) -- without it these two
  # rows would share one line instead of each getting its own.
  # `flex-bar` is mo/_top_nav.scss's `d-flex` + `justify-content-
  # between` + `align-items-center` alias.
  CONTAINER_CLASSES = %w[container-fluid px-3 w-100 flex-bar].freeze
  LEFT_CLASSES = %w[
    d-flex flex-row align-items-center flex-grow-1 navbar_left
  ].freeze
  RIGHT_CLASSES = %w[
    d-flex flex-row align-items-center justify-content-end navbar_right
  ].freeze

  # Controllers whose index pages are linkable from the rubric.
  # When the current page IS one of these and isn't the index
  # itself, the rubric becomes a link to the index.
  NAV_INDEXABLES = %w[
    observations names species_lists projects locations images herbaria
    glossary_terms comments rss_logs field_slips
  ].freeze

  # Controllers that support the green "+ Add" button. Description
  # / herbarium-record controllers are excluded: descriptions don't
  # get a create button at all, and herbarium records are created
  # from observation pages.
  NAV_CREATABLES = %w[
    observations names species_lists projects locations images herbaria
    glossary_terms field_slips articles publications
  ].freeze

  def view_template
    Navbar(variant: :default, class: "hidden-print mb-2", id: "top_nav") do
      render_top_row
      render_search_row
    end
  end

  private

  def render_top_row
    div(class: class_names(CONTAINER_CLASSES)) do
      div(class: class_names(LEFT_CLASSES)) { render_left }
      div(class: class_names(RIGHT_CLASSES)) { render_right }
    end
  end

  def render_left
    render_left_nav_toggle
    h4(class: "font-weight-bold mr-2", id: "rubric") { render_rubric }
    div(class: "mr-3 mr-sm-4 mr-lg-5") { render_nav_create }
  end

  def render_right
    render_search_nav_toggle
    render_nav_scan_qr_code
    ul(class: class_names("nav", Components::Navbar::NAV_CLASS,
                          Components::Navbar::RIGHT_CLASS,
                          "hidden-xs mr-0")) do
      # `content_for(:context_nav)` (no-block) returns the previously
      # stashed SafeBuffer; `trusted_html` emits it into Phlex's
      # buffer (a no-op `content_for` call would only read it).
      trusted_html(content_for(:context_nav)) if content_for?(:context_nav)
      render(UserNav.new(user: @user)) if @user
    end
    render(Login.new) if @user.nil?
  end

  def render_search_row
    div(class: class_names(CONTAINER_CLASSES)) do
      Collapsible(id: "search_nav", class: "w-100",
                  data: {
                    controller: "search-type",
                    # Stimulus Array values must be JSON. Rails' tag
                    # helper JSON-encodes arrays automatically; Phlex
                    # space-joins them ("a b"), which breaks
                    # JSON.parse in the controller and silently
                    # disables the help/advanced-search forms (#4492).
                    search_type_help_types_value: SEARCH_HELP_TYPES.to_json,
                    search_type_form_types_value: SEARCH_FORM_TYPES.to_json
                  }) do
        # Identify pages get their own filter bar; everything else
        # gets the pattern-search bar.
        if controller.controller_name == "identify"
          render(::Views::Controllers::Observations::Identify::FormFilter.new)
        else
          render(SearchBar.new(
                   search_help_types: SEARCH_HELP_TYPES,
                   search_form_types: SEARCH_FORM_TYPES
                 ))
        end
      end
    end
  end

  # The hamburger that opens the offcanvas sidebar on mobile /
  # small-tablet widths. Uses the MO favicon as the glyph.
  def render_left_nav_toggle
    div(class: "visible-xs visible-sm pr-3 pr-sm-4") do
      Button(
        variant: :outline,
        class: "rounded-circle overflow-hidden p-0",
        id: "left_nav_toggle",
        data: { toggle: "offcanvas", nav_target: "toggle",
                action: "nav#toggleOffcanvas" },
        aria: { expanded: "false", controls: "search_nav" }
      ) do
        img(src: asset_path("mo_icon_bg.svg"),
            width: "30px", alt: :menu.ti, title: :menu.ti)
      end
    end
  end

  # The magnifying-glass that toggles the collapsible search-bar
  # row below the top nav.
  def render_search_nav_toggle
    div(class: class_names(Components::Navbar::FORM_CLASS,
                           "px-2 px-sm-3")) do
      Button(
        type: :collapse_toggle,
        target_id: "search_nav",
        variant: :outline, size: :sm,
        class: "top_nav_button",
        aria: { expanded: "false", controls: "search_nav" }
      ) { Icon(type: :search, title: :search.ti) }
    end
  end

  # The page title in the navbar. Becomes a link to the
  # controller's index page when one exists AND the current page
  # isn't itself the index (with no extra params other than
  # `order_by`). Otherwise renders the plain rubric text.
  def render_rubric
    params = @query&.params&.except(:order_by)
    rubric_text = controller.rubric
    if action_name == "index" && (!params || params.blank?)
      plain(rubric_text)
    else
      render_nav_index_link(rubric_text)
    end
  end

  def render_nav_index_link(rubric_text)
    ctrlr = nav_linkable_controller
    return plain(rubric_text) unless ctrlr

    Link(
      type: :get, name: rubric_text,
      target: { controller: "/#{ctrlr.controller_path}", action: :index },
      class: "#{ctrlr.controller_name}_index_link",
      data: { tooltip_target: "tip", placement: :bottom,
              title: :index_object.ti(type: ctrlr.controller_name.to_sym) }
    )
  end

  # Resolves the controller whose index page the rubric links to.
  # For top-level controllers that's the current controller; for
  # nested controllers it's the parent module's controller (so
  # e.g. an action under `Names::DescriptionsController` rubric-
  # links to `NamesController#index`).
  def nav_linkable_controller
    parent = nav_linkable_parent_controller
    target = parent ? parent.constantize.new : controller
    return false unless target.methods.include?(:index) &&
                        NAV_INDEXABLES.include?(target.controller_name)

    target
  end

  def nav_linkable_parent_controller
    parent = controller.send(:parent_controller_module)
    return false if parent.blank?

    klass = "::#{parent}Controller"
    return false unless Object.const_defined?(klass)

    klass
  end

  # Green "+ Add" button next to the rubric. Mobile-sized form is
  # just the `+` glyph (long localizations like
  # "Listes d'observations [Ajouter]" don't fit on a 360px
  # viewport — matches iNat's mobile pattern, see #3930). The
  # "Add" word reappears at `sm` and above.
  def render_nav_create
    return unless nav_create_visible?

    Button(**nav_create_button_options)
  end

  def nav_create_visible?
    @user && controller.methods.include?(:new) &&
      NAV_CREATABLES.include?(controller.controller_name)
  end

  def nav_create_button_options
    full_label = nav_create_label
    { type: :new,
      target: url_for(controller: "/#{controller.controller_path}",
                      action: :new),
      name: :add.ti, label: true,
      variant: :success, size: :sm,
      class: "ml-1 mr-0 mx-sm-3 top_nav_button",
      title: full_label,
      aria: { label: full_label },
      data: { tooltip_target: "tip" } }
  end

  def nav_create_label
    obj_name = controller.controller_model_name.underscore.to_sym.ti
    [:new.ti, obj_name].safe_join(" ")
  end

  # QR-scanner link, only for the Observations / FieldSlips
  # controllers (the only two paths into the QR-code workflow).
  def render_nav_scan_qr_code
    return unless @user
    return unless %w[observations field_slips].include?(
      controller.controller_name
    )

    Button(
      type: :get,
      name: :app_qrcode.l,
      icon: :qrcode,
      target: field_slips_qr_reader_new_path,
      variant: :outline, size: :sm,
      class: "mx-0 mx-sm-2 top_nav_button"
    )
  end
end
