# frozen_string_literal: true

# Matrix box footer section component.
#
# Renders the footer section for a matrix box, handling:
# - Log footer (detail, time)
# - Identify footer (mark as reviewed toggle)
# - Custom footer components (when footer prop is an Array)
#
# @example
#   render MatrixBox::Footer.new(
#     data: render_data,
#     user: @user,
#     identify: true,
#     footer: []
#   )
class Components::MatrixBox::Footer < Components::Base
  prop :data, Hash
  prop :user, _Nilable(User), default: nil
  prop :identify, _Boolean, default: false
  prop :footer, _Union(Array, _Boolean), default: -> { [] }

  def view_template
    # Handle explicit footer components
    if @footer.is_a?(Array) && @footer.any?
      @footer.each { |component| render(component) }
      return
    end

    # Skip footer if explicitly false
    return if @footer == false

    # Default footers (when footer is [] or not provided)
    render_log_footer
    render_identify_footer
  end

  private

  def render_log_footer
    return unless @data[:detail].present? || @data[:time].present?

    div(class: "panel-footer log-footer") do
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
    div(class: "rss-what small") { time.display_time } if time
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

  def render_identify_footer
    return unless @identify && @data[:type] == :observation

    div(
      class: "panel-footer panel-active text-center position-relative"
    ) do
      mark_as_reviewed_toggle(
        @data[:id],
        "box_reviewed",
        "stretched-link"
      )
    end
  end
end
