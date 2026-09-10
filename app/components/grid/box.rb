# frozen_string_literal: true

# One item in a Grid -- a wrapper for a Panel component.
#
# The `<li>` and the Panel's `<div class="card h-100">` stay two
# separate elements deliberately: `height: 100%` on the card needs a
# distinct parent (the stretched `<li>`) to resolve against -- see
# `Components::Panel#view_template`'s comment.
#
# This component can be used in two ways:
# 1. With an object - calculates everything it needs from the @object and
#    renders a standard layout for Image, Observation, RssLog, or User
# 2. With a block - renders a simple <li> wrapper for custom content
#
# @example Standard object rendering
#   render Components::Grid::Box.new(user: @user, object: @observation)
#
# @example With custom options
#   render Components::Grid::Box.new(
#     user: @user,
#     object: @observation,
#     identify: true,
#     columns: Components::Column.classes_for(xs: 12)
#   )
#
# @example Custom block content
#   render Components::Grid::Box.new(id: 123, extra_class: "text-center") do
#     Panel do |panel|
#       panel.with_body { "Custom content" }
#     end
#   end
class Components::Grid::Box < Components::Base
  include Components::Grid::Box::RenderData
  include Components::Grid::Box::Footer

  # Properties
  prop :user, _Nilable(User), default: nil
  prop :object, _Nilable(AbstractModel), default: nil
  prop :id, _Nilable(_Union(Integer, String)), default: nil
  # Bare `.col` -- when rendered inside a `Components::Grid`
  # (the common case), that grid's `row-cols-*` utilities size
  # every box equally per breakpoint, so no per-breakpoint width class
  # is needed here. Callers rendering a box (or several) outside a
  # `Grid` -- a plain `Row(element: :ul)`, no `row-cols-*` --
  # override this explicitly, typically to
  # `Components::Column.classes_for(xs: 12)` for one-per-line stacking.
  prop :columns, String, default: "col"
  prop :extra_class, String, default: ""
  prop :identify, _Boolean, default: false
  prop :votes, _Boolean, default: true
  prop :footer, _Union(Array, _Boolean, nil), default: -> { [] }
  # Project context — when an observation box is rendered inside a
  # project-filtered observations grid, a project admin sees an Exclude
  # button that moves the observation to the project's excluded list.
  prop :project, _Nilable(Project), default: nil

  def view_template(&block)
    if @object
      render_object_layout(&block)
    elsif block
      render_custom_layout(&block)
    end
  end

  private

  def render_object_layout(&custom_footer)
    # Build render data from object
    @data = build_render_data
    # Get observation_view from eager-loaded association (nil if not loaded)
    @observation_view = observation_view_for_identify if @identify

    li(
      id: "box_#{@data[:id]}",
      class: class_names("grid-box", @columns, @extra_class)
    ) do
      # Deliberately NOT subscribed to [image, :processed] broadcasts:
      # rotate/mirror only happens on the image-show page, so only
      # that page (Views::Controllers::Images::Show::ImagePanel)
      # live-updates. A grid page
      # with dozens of boxes would otherwise open a websocket
      # subscription (plus a solid_cable MAX(id) query) per thumbnail
      # for an event that can't happen from this page; it catches up
      # on the next load via the #4808 cache-busting URL token.
      # `h-100`: fills the row's stretched height (BS4's `.row`
      # defaults to `align-items: stretch`, so `<li>` siblings already
      # match height -- this makes the card fill its `<li>` too).
      Panel(panel_class: "h-100") do |panel|
        render_thumbnail_section(panel)
        render_details_section(panel)
        render_log_footer(panel)
        render_identify_footer(panel)
        render_project_admin_footer(panel)
        render_custom_footer(panel, &custom_footer) if custom_footer
      end
    end
  end

  # Get or build observation_view from eager-loaded association.
  # Returns nil if not an observation or association not loaded.
  def observation_view_for_identify
    return nil unless @data[:type] == :observation

    obs = @data[:what]
    # returns true if association was eager loaded, even if no o_v for this obs
    return nil unless obs.observation_views.loaded?

    obs.observation_views.find { |ov| ov.user_id == @user&.id } ||
      ObservationView.new(observation: obs, user: @user)
  end

  def render_custom_layout(&block)
    li(
      id: @id ? "box_#{@id}" : nil,
      class: class_names("grid-box", @columns, @extra_class),
      &block
    )
  end

  # Render image section
  def render_thumbnail_section(panel)
    return unless @data[:image]

    panel.with_thumbnail do
      InteractiveImage(
        user: @user,
        image: @data[:image],
        image_link: @data[:image_link],
        obs: @data[:obs] || {},
        votes: @votes && @data.fetch(:votes, true),
        full_width: @data.fetch(:full_width, true),
        identify: @identify,
        observation_view: @observation_view
      )
    end
  end

  # Render details section
  def render_details_section(panel)
    panel.with_body(classes: "log-details log-text") do
      render_what_section
      ul(class: "list-unstyled") do
        render_where_section
        render_when_who_section
        render_source_credit
        render_occurrence_link
      end
    end
  end

  def render_what_section
    h_style = @data[:image] ? "h5" : "h3"

    div(class: "log-what") do
      div(class: "log-heading") do
        h5(class: class_names(["mt-0"], h_style)) do
          Link(type: :get, name: @data[:name],
               target: @data[:what].show_link_args) { render_title }
        end
        whitespace
        IDBadge(object: @data[:what], size: :lg, extra_class: nil)
      end

      render_identify_ui if @identify
    end
  end

  def render_title
    render(Components::Grid::Box::Title.new(
             id: @data[:id],
             name: @data[:name],
             type: @data[:type]
           ))
  end

  def render_occurrence_link
    return unless (occ = @data[:occurrence])

    obs_count = if occ.observations.loaded?
                  occ.observations.size
                else
                  occ.observations.count
                end
    return unless obs_count > 1

    li(class: "hanging-indent mt-3") do
      Link(type: :get, target: occurrence_path(occ),
           name: :matrix_box_occurrence.l, icon: :matrix, label: true,
           class: "occurrence-link")
    end
  end

  def render_identify_ui
    return unless @data[:type] == :observation && @data[:consensus]

    consensus = @data[:consensus]
    obs = @data[:what]

    if (obs.name_id != 1) && (naming = consensus.consensus_naming)
      div(
        class: "vote-select-container mb-3",
        data: { vote_cache: obs.vote_cache }
      ) do
        render(Views::Controllers::Observations::Namings::Votes::Form.new(
                 naming: naming, user: @user, vote: nil,
                 context: "grid_box"
               ))
      end
    else
      render_propose_naming_modal(obs)
    end
  end

  def render_propose_naming_modal(obs)
    Button(
      type: :modal,
      name: :create_naming.t,
      target: new_observation_naming_path(
        observation_id: obs.id, context: "grid_box"
      ),
      modal_id: "obs_#{obs.id}_naming",
      class: "d-inline-block mb-3 propose-naming-link"
    )
  end

  def render_where_section
    return unless @data[:where]

    li(class: "log-where hanging-indent") do
      Link(type: :location,
           where: @data[:where],
           location: @data[:location])
    end
  end

  def render_when_who_section
    return if @data[:when].blank?

    li(class: "log-when-who hanging-indent") do
      span(class: "nowrap-ellipsis") do
        span(class: "log-when") { @data[:when] }
        plain(": ")
        Link(type: :user,
             user: @data[:who],
             attributes: { class: "log-who" })
      end
    end
  end

  def render_source_credit
    target = @data[:what]
    return unless target.respond_to?(:source_noteworthy?) &&
                  target.source_noteworthy?

    li(class: "log-source-credit hanging-indent mt-3") do
      render_source_credit_inner(target)
    end
  end

  # External imports get a Phlex-rendered link so we can set
  # target="_blank" / rel="noopener" — textile has no syntax for
  # those attributes. Enum credits go through .tl (inline, no <div>
  # wrapper -- needed to sit next to the bold "via" on one line).
  # `source_noteworthy?` (the caller's guard) guarantees `source` is
  # present whenever `import_link` isn't, so the enum branch is safe
  # with no presence check needed here.
  def render_source_credit_inner(target)
    if (link = target.import_link)
      render_external_credit_link(link)
    else
      b { plain(:via.l) }
      whitespace
      trusted_html(:"source_credit_#{target.source}".l.tl)
    end
  end

  # An import link's URL always resolves (stored override or derived from the
  # site template via link_url), so the credit always renders as a link.
  def render_external_credit_link(link)
    Link(type: :external,
         content: :source_credit_external_text.l(name: link.external_site.name),
         path: link.link_url)
  end
end
