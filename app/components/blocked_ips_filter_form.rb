# frozen_string_literal: true

# Superform component for filtering blocked IPs by prefix.
# Renders a LiveDataFilterNav as a sibling to a filter text field form.
#
# @example Usage in ERB
#   <%= render(Components::BlockedIpsFilterForm.new(
#         FormObject::TextFilter.new(starts_with: @starts_with),
#         page: @blocked_ips_page,
#         total_pages: @blocked_ips_pages,
#         filter_path: edit_admin_blocked_ips_path
#       )) %>
#
class Components::BlockedIpsFilterForm < Components::ApplicationForm
  # @param filter [FormObject::TextFilter] the filter form object
  # @param page [Integer] current page number
  # @param total_pages [Integer] total number of pages
  # @param filter_path [String] path for form submission and pagination
  def initialize(filter, page:, total_pages:, filter_path:, **)
    @page = page
    @total_pages = total_pages
    @filter_path = filter_path
    super(filter, **)
  end

  def around_template(&block)
    render(Components::LiveDataFilterNav.new(
             page: @page,
             total_pages: @total_pages,
             prev_path: prev_path,
             next_path: next_path
           )) do |nav|
      nav.with_form { super(&block) }
    end
  end

  def view_template
    text_field(:starts_with,
               label: false,
               placeholder: "Filter by IP prefix...",
               class: "form-control form-control-sm",
               size: 21,
               data: { action: "input->autosubmit#submit" })
  end

  private

  def form_tag(&block)
    form(action: @filter_path, method: :get, **form_attributes, &block)
  end

  def form_attributes
    {
      id: "blocked_ips_filter_form",
      class: "d-inline-block",
      data: {
        controller: "autosubmit",
        turbo_frame: "blocked_ips_list"
      }
    }
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
    params = { page: page }
    if model.starts_with.present?
      params[:text_filter] = { starts_with: model.starts_with }
    end
    "#{@filter_path}?#{params.to_query}"
  end
end
