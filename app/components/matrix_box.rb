# frozen_string_literal: true

# Matrix box component for displaying objects in a responsive grid.
# Essentially a wrapper for a Panel component
#
# This component can be used in two ways:
# 1. With an object - calculates everything it needs from the @object and
#    renders a standard layout for Image, Observation, RssLog, or User
# 2. With a block - renders a simple <li> wrapper for custom content
#
# @example Standard object rendering
#   render MatrixBox.new(user: @user, object: @observation)
#
# @example With custom options
#   render MatrixBox.new(
#     user: @user,
#     object: @observation,
#     identify: true,
#     columns: "col-xs-12 col-sm-6"
#   )
#
# @example Custom block content
#   render MatrixBox.new(id: 123, extra_class: "text-center") do
#     tag.div(class: "panel panel-default") { "Custom content" }
#   end
class Components::MatrixBox < Components::Base
  include Components::MatrixBox::RenderData
  include Phlex::Rails::Helpers::LinkTo
  include Phlex::Rails::Helpers::ClassNames

  # Properties
  prop :user, _Nilable(User), default: nil
  prop :object, _Nilable(AbstractModel), default: nil
  prop :id, _Nilable(_Union(Integer, String)), default: nil
  prop :columns, String, default: "col-xs-12 col-sm-6 col-md-4 col-lg-3"
  prop :extra_class, String, default: ""
  prop :identify, _Boolean, default: false
  prop :footer, _Union(Array, _Boolean, nil), default: -> { [] }

  def view_template(&block)
    if @object
      render_object_layout
    elsif block
      render_custom_layout(&block)
    end
  end

  private

  def render_object_layout
    # Build render data from object
    @data = build_render_data

    li(
      id: "box_#{@data[:id]}",
      class: class_names("matrix-box", @columns, @extra_class)
    ) do
      Panel(sizing: true) do |panel|
        render_thumbnail_section(panel)
        render_details_section(panel)
        render_log_footer(panel)
        render_identify_footer(panel)
      end
    end
  end

  def render_custom_layout(&block)
    li(
      id: @id ? "box_#{@id}" : nil,
      class: class_names("matrix-box", @columns, @extra_class),
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
        votes: @data.fetch(:votes, true),
        full_width: @data.fetch(:full_width, true),
        identify: @identify
      )
    end
  end

  # Render details section
  def render_details_section(panel)
    panel.with_body(classes: "rss-box-details") do
      render_what_section
      render_where_section
      render_when_who_section
      render_source_credit
    end
  end

  def render_what_section
    h_style = @data[:image] ? "h5" : "h3"

    div(class: "rss-what") do
      h5(class: class_names(%w[mt-0 rss-heading], h_style)) do
        a(href: url_for(@data[:what].show_link_args)) do
          render_title
        end
        render_id_badge(@data[:what])
      end

      render_identify_ui if @identify
    end
  end

  def render_title
    MatrixBoxTitle(
      id: @data[:id],
      name: @data[:name],
      type: @data[:type]
    )
  end

  def render_id_badge(obj)
    whitespace
    show_title_id_badge(obj, "rss-id")
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
        naming_vote_form(naming, nil, context: "matrix_box")
      end
    else
      propose_naming_link(
        obs.id,
        btn_class: "btn btn-default d-inline-block mb-3",
        context: "matrix_box"
      )
    end
  end

  def render_where_section
    return unless @data[:where]

    div(class: "rss-where") do
      small { location_link(@data[:where], @data[:location]) }
    end
  end

  def render_when_who_section
    return if @data[:when].blank?

    div(class: "rss-what") do
      small(class: "nowrap-ellipsis") do
        span(class: "rss-when") { @data[:when] }
        plain(": ")
        user_link(@data[:who], nil, class: "rss-who")
      end
    end
  end

  def render_source_credit
    target = @data[:what]
    return unless target.respond_to?(:source_credit) &&
                  target.source_noteworthy?

    div(class: "small mt-3") do
      div(class: "source-credit") do
        small { target.source_credit.tpl }
      end
    end
  end

  def render_log_footer(panel)
    return unless @data[:detail].present? || @data[:time].present?

    panel.with_footer(classes: "log-footer") do
      render_footer_detail(@data[:detail])
      render_footer_time(@data[:time])
    end
  end

  def render_footer_detail(detail)
    return if detail.blank?

    if detail.is_a?(User)
      render_user_detail(detail)
    else
      div(class: "rss-detail small") { detail }
    end
  end

  def render_footer_time(time)
    return unless time

    div(
      class: "rss-what rss-updated-at small",
      data: { controller: "local-time", local_time_utc_value: time.utc.iso8601 }
    ) do
      # Server-rendered fallback for no-JS clients; replaced by Stimulus
      time.display_time
    end
  end

  def render_user_detail(user)
    div(class: "rss-detail small") do
      plain("#{:list_users_joined.l}: #{user.created_at.web_date}")
      br
      plain("#{:list_users_contribution.l}: #{user.contribution}")
      br
      link_to(
        :OBSERVATIONS.l,
        observations_path(by_user: user.id)
      )
    end
  end

  def render_identify_footer(panel)
    return unless @identify

    panel.with_footer(classes: "panel-active text-center position-relative") do
      mark_as_reviewed_toggle(
        @data[:id],
        "box_reviewed",
        "stretched-link"
      )
    end
  end
end
