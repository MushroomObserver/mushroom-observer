# frozen_string_literal: true

# Matrix box component for displaying objects in a responsive grid.
#
# This component can be used in two ways:
# 1. With an object - renders the standard layout for Image, Observation, RssLog, or User
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
  include Phlex::Rails::Helpers::LinkTo

  # Properties
  prop :user, _Nilable(User), default: nil
  prop :object, _Nilable(Object), default: nil
  prop :id, _Nilable(_Union(Integer, String)), default: nil
  prop :columns, String, default: "col-xs-12 col-sm-6 col-md-4 col-lg-3"
  prop :extra_class, String, default: ""
  prop :identify, _Boolean, default: false
  prop :header, Array, default: -> { [] }
  prop :footer, _Union(Array, _Boolean), default: -> { [] }

  def view_template(&block)
    if object
      render_object_layout
    elsif block
      render_custom_layout(&block)
    end
  end

  private

  def render_object_layout
    # Build render data from object
    render_data = build_render_data

    li(
      id: "box_#{render_data[:id]}",
      class: class_names("matrix-box", columns, extra_class)
    ) do
      div(class: "panel panel-default") do
        # Header components (if any)
        header.each { |component| unsafe_raw(component) } if header.any?

        # Main content: image and details
        div(class: "panel-sizing") do
          render_image_section(render_data)
          render_details_section(render_data)
        end

        # Footer components
        render_footer_section(render_data)
      end
    end
  end

  def render_custom_layout(&block)
    li(
      id: id ? "box_#{id}" : nil,
      class: class_names("matrix-box", columns, extra_class),
      &block
    )
  end

  # Build render data based on object type
  def build_render_data
    case object
    when Image
      extract_image_data
    when Observation
      extract_observation_data
    when RssLog
      extract_rss_log_data
    when User
      extract_user_data
    else
      { id: object.id, type: :unknown }
    end
  end

  def extract_image_data
    {
      id: object.id,
      type: :image,
      when: (object.when.web_date rescue nil),
      who: object.user,
      name: object.unique_format_name.t,
      what: object,
      where: nil,
      location: nil,
      image: object,
      image_link: object.show_link_args,
      full_width: true
    }
  end

  def extract_observation_data
    data = {
      id: object.id,
      type: :observation,
      when: object.when.web_date,
      who: object.user,
      name: object.user_format_name(object.user).t.break_name.small_author,
      what: object,
      where: object.where,
      location: object.location,
      consensus: Observation::NamingConsensus.new(object),
      detail: object.rss_log&.detail,
      time: object.rss_log&.updated_at
    }

    if object.thumb_image_id
      data[:image] = object.thumb_image
      data[:image_link] = object.show_link_args
      data[:obs] = object
      data[:full_width] = true
    end

    data
  end

  def extract_rss_log_data
    target = object.target
    data = {
      id: target&.id || object.id,
      type: object.target_type || :rss_log,
      when: target.respond_to?(:when) ? target.when&.web_date : nil,
      who: target&.user,
      what: target || object,
      detail: object.detail,
      time: object.updated_at
    }

    data[:name] = if object.target_type == :image
                    target.unique_format_name.t
                  elsif target
                    target.format_name.t.break_name.small_author
                  else
                    object.format_name.t.break_name.small_author
                  end

    if target.respond_to?(:location)
      data[:where] = target.where
      data[:location] = target.location
    end

    if target.respond_to?(:thumb_image) && target&.thumb_image
      data[:image] = target.thumb_image
      data[:image_link] = target.show_link_args
      data[:obs] = target if target.respond_to?(:is_collection_location)
      data[:full_width] = true
    end

    data
  end

  def extract_user_data
    data = {
      id: object.id,
      type: :user,
      detail: object,
      name: object.unique_text_name,
      what: object,
      where: object.location&.name,
      location: object.location
    }

    if object.image_id
      data[:image] = object.image
      data[:image_link] = object.show_link_args
      data[:votes] = false
      data[:full_width] = true
    end

    data
  end

  # Render image section
  def render_image_section(data)
    return unless data[:image]

    div(class: "thumbnail-container") do
      render InteractiveImage.new(
        user: user,
        image: data[:image],
        image_link: data[:image_link],
        obs: data[:obs] || {},
        votes: data.fetch(:votes, true),
        full_width: data.fetch(:full_width, true)
      )
    end
  end

  # Render details section
  def render_details_section(data)
    div(class: "panel-body rss-box-details") do
      render_what_section(data)
      render_where_section(data)
      render_when_who_section(data)
      render_source_credit(data)
    end
  end

  def render_what_section(data)
    h_style = data[:image] ? "h5" : "h3"

    div(class: "rss-what") do
      h5(class: class_names(%w[mt-0 rss-heading], h_style)) do
        a(href: helpers.url_for(data[:what].show_link_args)) do
          render_title(data)
        end
        render_id_badge(data[:what])
      end

      render_identify_ui(data) if identify
    end
  end

  def render_title(data)
    fragment("box_title") do
      bold = [:observation, :name].include?(data[:type]) ? "" : " font-weight-bold"
      span(data[:name], class: class_names("rss-name", bold),
                        id: "box_title_#{data[:id]}")
    end
  end

  def render_id_badge(obj)
    whitespace
    unsafe_raw(helpers.show_title_id_badge(obj, "rss-id"))
  end

  def render_identify_ui(data)
    return unless data[:type] == :observation && data[:consensus]

    consensus = data[:consensus]
    obs = data[:what]

    if (obs.name_id != 1) && (naming = consensus.consensus_naming)
      div(
        class: "vote-select-container mb-3",
        data: { vote_cache: obs.vote_cache }
      ) do
        unsafe_raw(helpers.naming_vote_form(naming, nil, context: "matrix_box"))
      end
    else
      unsafe_raw(
        helpers.propose_naming_link(
          obs.id,
          btn_class: "btn btn-default d-inline-block mb-3",
          context: "matrix_box"
        )
      )
    end
  end

  def render_where_section(data)
    return unless data[:where]

    div(class: "rss-where") do
      small do
        unsafe_raw(helpers.location_link(data[:where], data[:location]))
      end
    end
  end

  def render_when_who_section(data)
    return if data[:when].blank?

    div(class: "rss-what") do
      small(class: "nowrap-ellipsis") do
        span(data[:when], class: "rss-when")
        plain(": ")
        unsafe_raw(helpers.user_link(data[:who], nil, class: "rss-who"))
      end
    end
  end

  def render_source_credit(data)
    target = data[:what]
    return unless target.respond_to?(:source_credit) &&
                  target.source_noteworthy?

    div(class: "small mt-3") do
      div(class: "source-credit") do
        small do
          unsafe_raw(target.source_credit.tpl)
        end
      end
    end
  end

  # Render footer section
  def render_footer_section(data)
    # Handle explicit footer components
    if footer.is_a?(Array)
      footer.each { |component| unsafe_raw(component) } if footer.any?
      return
    end

    # Skip footer if explicitly false
    return if footer == false

    # Default footers
    render_log_footer(data)
    render_identify_footer(data)
  end

  def render_log_footer(data)
    return unless data[:detail].present? || data[:time].present?

    div(class: "panel-footer log-footer") do
      if data[:detail].is_a?(User)
        render_user_detail(data[:detail])
      elsif data[:detail].present?
        div(data[:detail], class: "rss-detail small")
      end

      if data[:time]
        div(data[:time].display_time, class: "rss-what small")
      end
    end
  end

  def render_user_detail(user)
    div(class: "rss-detail small") do
      plain("#{:list_users_joined.l}: #{user.created_at.web_date}")
      br
      plain("#{:list_users_contribution.l}: #{user.contribution}")
      br
      unsafe_raw(
        helpers.link_to(
          :OBSERVATIONS.l,
          helpers.observations_path(by_user: user.id)
        )
      )
    end
  end

  def render_identify_footer(data)
    return unless identify && data[:type] == :observation

    div(
      class: "panel-footer panel-active text-center position-relative"
    ) do
      unsafe_raw(
        helpers.mark_as_reviewed_toggle(
          data[:id],
          "box_reviewed",
          "stretched-link"
        )
      )
    end
  end

  def helpers
    @helpers ||= ApplicationController.helpers
  end
end
