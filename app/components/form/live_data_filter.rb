# frozen_string_literal: true

# Superform component for filtering paginated data by text prefix.
# Renders prev/next pagination buttons with a filter text field between them.
#
# @example Usage
#   <%= render(Components::Form::LiveDataFilter.new(
#         FormObject::TextFilter.new(starts_with: @starts_with),
#         turbo_frame: "blocked_ips_list",
#         page: @page,
#         total_pages: @total_pages,
#         filter_path: edit_admin_blocked_ips_path
#       )) %>
#
class Components::Form::LiveDataFilter < Components::ApplicationForm
  # `filter` (positional) is the base class's own `model` prop --
  # never referenced under its own name here, only forwarded to
  # `super`.
  prop :turbo_frame, String
  prop :page, Integer
  prop :total_pages, Integer
  prop :filter_path, String
  prop :placeholder, String, default: "Filter..."
  prop :page_param, String, default: "page"
  prop :filter_param, String, default: "text_filter"

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
      # Merge in @attributes[:data] so ApplicationForm's data-turbo
      # actually reaches this overridden form_tag.
      data: (@attributes[:data] || {}).merge(
        controller: "autosubmit",
        turbo_frame: @turbo_frame
      )
    }
  end

  # GET forms don't need authenticity tokens or _method fields
  def authenticity_token_field; end
  def _method_field; end

  # Override Superform's key to use filter_param for input naming.
  # This ensures blocked/okay filters have unique param and ID names:
  # - blocked: name="text_filter[starts_with]" id="text_filter_starts_with"
  # - okay: name="okay_filter[starts_with]" id="okay_filter_starts_with"
  def key
    @filter_param
  end

  def render_prev_button
    Button(
      type: :get,
      name: "« Prev",
      target: prev_path || "#",
      size: :sm,
      class: ("opacity-0" unless show_prev?),
      disabled: !show_prev?
    )
  end

  def render_next_button
    Button(
      type: :get,
      name: "Next »",
      target: next_path || "#",
      size: :sm,
      class: ("opacity-0" unless show_next?),
      disabled: !show_next?
    )
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
