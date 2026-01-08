# frozen_string_literal: true

# Superform component for filtering paginated data by text prefix.
# Renders prev/next pagination buttons with a filter text field between them.
#
# @example Usage
#   <%= render(Components::LiveDataFilterForm.new(
#         FormObject::TextFilter.new(starts_with: @starts_with),
#         turbo_frame: "blocked_ips_list",
#         page: @page,
#         total_pages: @total_pages,
#         filter_path: edit_admin_blocked_ips_path
#       )) %>
#
class Components::LiveDataFilterForm < Components::ApplicationForm
  # @param filter [FormObject::TextFilter] the filter form object
  # @param turbo_frame [String] the turbo frame ID to target
  # @param page [Integer] current page number
  # @param total_pages [Integer] total number of pages
  # @param filter_path [String] path for form submission and pagination
  # @param placeholder [String] placeholder text for the filter input
  # @param page_param [String] param name for page number (default: "page")
  # @param filter_param [String] param namespace for filter
  #   (default: "text_filter")
  def initialize(filter, turbo_frame:, page:, total_pages:, filter_path:, # rubocop:disable Metrics/ParameterLists
                 placeholder: "Filter...", page_param: "page",
                 filter_param: "text_filter", **)
    @turbo_frame = turbo_frame
    @page = page
    @total_pages = total_pages
    @filter_path = filter_path
    @placeholder = placeholder
    @page_param = page_param
    @filter_param = filter_param
    super(filter, **)
  end

  def around_template(&block)
    nav(class: "d-flex justify-content-between align-items-center p-3",
        style: "order: 2") do
      render_prev_button
      super(&block)
      render_next_button
    end
  end

  def view_template
    div(class: "text-center") do
      text_field(:starts_with,
                 label: false,
                 placeholder: @placeholder,
                 class: "form-control form-control-sm d-inline-block w-auto",
                 size: 21,
                 data: { action: "input->autosubmit#submit" })
    end
  end

  private

  def form_tag(&block)
    form(action: @filter_path, method: :get, **form_attributes, &block)
  end

  def form_attributes
    {
      id: "#{@turbo_frame.tr("_", "-")}-filter-form",
      class: "d-inline-block",
      data: {
        controller: "autosubmit",
        turbo_frame: @turbo_frame
      }
    }
  end

  def render_prev_button
    a(href: prev_path || "#",
      class: class_names("btn btn-default btn-sm", "opacity-0": !show_prev?),
      disabled: !show_prev?) { "« Prev" }
  end

  def render_next_button
    a(href: next_path || "#",
      class: class_names("btn btn-default btn-sm", "opacity-0": !show_next?),
      disabled: !show_next?) { "Next »" }
  end

  def show_prev?
    @page > 1
  end

  def show_next?
    @page < @total_pages
  end

  def prev_path
    return nil unless @page > 1

    build_path(page: @page - 1)
  end

  def next_path
    return nil unless @page < @total_pages

    build_path(page: @page + 1)
  end

  def build_path(page:)
    params = { @page_param => page }
    if model.starts_with.present?
      params[@filter_param] = { starts_with: model.starts_with }
    end
    "#{@filter_path}?#{params.to_query}"
  end
end
