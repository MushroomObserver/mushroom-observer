# frozen_string_literal: true

module Views::Controllers::VisualGroups
  # Combined filter form on a visual group's edit page: status
  # (button-group) + filter text input. Both are inside one form so
  # clicking a status submit button carries the current text along,
  # and submitting the text input preserves the current status via
  # the hidden status field.
  class FilterForm < Components::ApplicationForm
    STATUSES = [
      ["needs_review", :visual_group_needs_review],
      ["included", :visual_group_included],
      ["excluded", :visual_group_excluded]
    ].freeze

    prop :visual_group, ::VisualGroup

    # Accept optional model arg for ModalForm compatibility (ignored
    # -- we create our own FormObject). Pattern B: form creates
    # FormObject internally.
    def initialize(_model = nil, visual_group:, status:, filter:, **)
      super(FormObject::VisualGroupFilter.new(status:, filter:),
            visual_group: visual_group, turbo: false, **)
    end

    def view_template
      super do
        # Hidden status field: preserves the current status when the
        # user submits via the text-input's submit. The status submit
        # buttons below carry their own `name="status" value="<s>"`;
        # because the hidden field appears FIRST in the DOM, the
        # button's value (later in DOM) wins in Rails' last-value-wins
        # param parsing.
        hidden_field(:status)
        render_status_button_row
        render_filter_text_row
      end
    end

    private

    def form_tag(&block)
      form(action: form_action, method: :get,
           **form_attributes, &block)
    end

    def form_action
      edit_visual_group_path(@visual_group)
    end

    def form_attributes
      {
        id: "visual_group_filters_form",
        class: "form-inline mb-4",
        data: @attributes[:data] || {}
      }
    end

    # GET forms don't need authenticity tokens or _method fields
    def authenticity_token_field; end
    def _method_field; end

    def render_status_button_row
      div(class: "d-flex gap-2 align-items-center mb-3") do
        strong(class: "mb-0") do
          plain("#{:edit_visual_group_filter_options.t}:")
        end
        ButtonGroup do
          STATUSES.each do |(value, label_key)|
            render_status_button(value, label_key.t)
          end
        end
        render_reload_link if model.status == "needs_review"
      end
    end

    def render_status_button(value, label)
      if model.status == value
        Button(
          name: label, variant: :outline,
          tag: :span, aria_disabled: "true",
          class: "active disabled"
        )
      else
        Button(
          type: :submit,
          name: label,
          html_name: "visual_group_filter[status]",
          value: value,
          variant: :outline
        )
      end
    end

    # Force-reload button for the needs_review view, which pulls
    # fresh inference data on each load. We need a true cache-bypass
    # reload: a same-URL self-link would let Turbo Drive serve its
    # snapshot (stale data), and HTTP-layer caching is less reliable
    # than the explicit `reload(true)` for force-refetch. Phlex's
    # native `a` strips `javascript:` hrefs as a safety measure, but
    # the registered Rails `link_to` helper keeps them.
    def render_reload_link
      Button(
        name: :reload.ti,
        class: "ml-2",
        onclick: "window.location.reload(true)"
      )
    end

    def render_filter_text_row
      div(class: "d-flex gap-2 align-items-end") do
        text_field(:filter, label: "Filter text", wrap_class: "mb-0",
                            size: 40)
        submit(:edit_visual_group_update_filter.t)
      end
    end
  end
end
