# frozen_string_literal: true

# Matrix box component for displaying objects in a responsive grid.
#
# This component can be used in two ways:
# 1. With an object - renders the standard layout for Image, Observation,
#    RssLog, or User
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
  include Phlex::Rails::Helpers::ClassNames

  # Properties
  prop :user, _Nilable(User), default: nil
  prop :object, _Nilable(Object), default: nil
  prop :id, _Nilable(_Union(Integer, String)), default: nil
  prop :columns, String, default: "col-xs-12 col-sm-6 col-md-4 col-lg-3"
  prop :extra_class, String, default: ""
  prop :identify, _Boolean, default: false
  prop :header, Array, default: -> { [] }
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
    render_data = build_render_data

    li(
      id: "box_#{render_data[:id]}",
      class: class_names("matrix-box", @columns, @extra_class)
    ) do
      div(class: "panel panel-default") do
        # Header components (if any)
        @header.each { |component| render(component) } if @header.any?

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
      id: @id ? "box_#{@id}" : nil,
      class: class_names("matrix-box", @columns, @extra_class),
      &block
    )
  end

  # Build render data based on object type
  def build_render_data
    case @object
    when ::Image
      extract_image_data
    when Observation
      extract_observation_data
    when RssLog
      extract_rss_log_data
    when User
      extract_user_data
    else
      { id: @object.id, type: :unknown }
    end
  end

  def extract_image_data
    {
      id: @object.id,
      type: :image,
      when: begin
              @object.when.web_date
            rescue StandardError
              nil
            end,
      who: @object.user,
      name: @object.unique_format_name.t,
      what: @object,
      where: nil,
      location: nil,
      image: @object,
      image_link: @object.show_link_args,
      full_width: true
    }
  end

  def extract_observation_data # rubocop:disable Metrics/AbcSize
    data = {
      id: @object.id,
      type: :observation,
      when: @object.when.web_date,
      who: @object.user,
      name: @object.user_format_name(@object.user).t.break_name.small_author,
      what: @object,
      where: @object.where,
      location: @object.location,
      consensus: Observation::NamingConsensus.new(@object),
      detail: @object.rss_log&.detail,
      time: @object.rss_log&.updated_at
    }

    add_observation_image_data(data) if @object.thumb_image_id
    data
  end

  def add_observation_image_data(data)
    data[:image] = @object.thumb_image
    data[:image_link] = @object.show_link_args
    data[:obs] = @object
    data[:full_width] = true
  end

  def extract_rss_log_data
    target = @object.target
    data = {
      id: target&.id || @object.id,
      type: @object.target_type || :rss_log,
      when: target.respond_to?(:when) ? target.when&.web_date : nil,
      who: target&.user,
      what: target || @object,
      detail: @object.detail,
      time: @object.updated_at
    }

    data[:name] = extract_rss_log_name(target)
    add_rss_log_location_data(data, target)
    add_rss_log_image_data(data, target)
    data
  end

  def extract_rss_log_name(target)
    if @object.target_type == :image
      target.unique_format_name.t
    elsif target
      target.format_name.t.break_name.small_author
    else
      @object.format_name.t.break_name.small_author
    end
  end

  def add_rss_log_location_data(data, target)
    return unless target.respond_to?(:location)

    data[:where] = target.where
    data[:location] = target.location
  end

  def add_rss_log_image_data(data, target)
    return unless target.respond_to?(:thumb_image) && target&.thumb_image

    data[:image] = target.thumb_image
    data[:image_link] = target.show_link_args
    data[:obs] = target if target.respond_to?(:is_collection_location)
    data[:full_width] = true
  end

  def extract_user_data
    data = {
      id: @object.id,
      type: :user,
      detail: @object,
      name: @object.unique_text_name,
      what: @object,
      where: @object.location&.name,
      location: @object.location
    }

    add_user_image_data(data) if @object.image_id
    data
  end

  def add_user_image_data(data)
    data[:image] = @object.image
    data[:image_link] = @object.show_link_args
    data[:votes] = false
    data[:full_width] = true
  end

  # Render image section
  def render_image_section(data)
    return unless data[:image]

    div(class: "thumbnail-container") do
      render(InteractiveImage.new(
               user: @user,
               image: data[:image],
               image_link: data[:image_link],
               obs: data[:obs] || {},
               votes: data.fetch(:votes, true),
               full_width: data.fetch(:full_width, true)
             ))
    end
  end

  # Render details section
  def render_details_section(data)
    render(Components::MatrixBoxDetails.new(
             data: data,
             user: @user,
             identify: @identify
           ))
  end

  # Render footer section
  def render_footer_section(data)
    render(Components::MatrixBoxFooter.new(
             data: data,
             user: @user,
             identify: @identify,
             footer: @footer
           ))
  end
end
