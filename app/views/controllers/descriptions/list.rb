# frozen_string_literal: true

# Renders the alt-descriptions list for a Name or Location show page:
# each visible description as a `<div>` (Names) or joined with `<br>`
# (Locations), containing a link to the description + its mod-controls.
# Wraps the existing `DescriptionsHelper#list_descriptions` helper
# rather than re-implementing the filter / sort / link / mod-link
# chain inline — that chain composes 5+ helper methods (`reviewer?`,
# `in_admin_mode?`, `sort_description_list`, `make_list_links`,
# `DescriptionIconsHelper#description_mod_links`, etc.); per
# `.claude/rules/phlex_conversions.md`, helpers that themselves compose
# other helpers stay registered for now.
module Views::Controllers::Descriptions
  class List < Views::Base
    register_value_helper :list_descriptions

    prop :user, _Nilable(::User), default: nil
    prop :object, _Any
    prop :type, Symbol
    prop :current, _Nilable(_Any), default: nil
    # When the object has no visible descriptions, emit this text
    # instead. Callers pass the type-specific i18n message
    # (`:show_name_no_descriptions.t`, etc.) — pre-translated so the
    # view stays type-agnostic. Pass an html_safe string (or
    # `SafeBuffer`) to embed inline markup like an `indent` span.
    prop :empty_text, _Nilable(String), default: nil
    # `:div` (Names): wrap each item in its own `<div>`. `:br`
    # (Locations): join items with `<br/>` separators (preserves the
    # pre-Phlex `safe_join(safe_br)` shape of the locations partial).
    prop :separator, Symbol, default: :div

    def view_template
      if items.any?
        render_items
      elsif @empty_text
        trusted_html(@empty_text.to_s)
      end
    end

    private

    def items
      list_descriptions(user: @user, object: @object,
                        type: @type, current: @current) || []
    end

    def render_items
      case @separator
      when :br
        items.each_with_index do |item, idx|
          br if idx.positive?
          trusted_html(item)
        end
      else
        items.each { |item| div { trusted_html(item) } }
      end
    end
  end
end
