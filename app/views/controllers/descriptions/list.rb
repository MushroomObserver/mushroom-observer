# frozen_string_literal: true

# Renders the alt-descriptions list for a Name or Location show page:
# each visible description as a `<div>` containing a link to the
# description + its mod-controls (Edit / Destroy when the user has
# the appropriate permission).
#
# Owns the full filter / sort / link / mod-link chain that the
# pre-Phlex `DescriptionsHelper#list_descriptions` +
# `#sort_description_list` + `#make_list_links` + `#description_link`
# + `#description_title` + `DescriptionIconsHelper#description_mod_links`
# composed. The helper still exists for one remaining caller in
# `tabs/observations_helper.rb#obs_name_description_tabs`; once the
# `_name_info.erb` partial migrates to Phlex (which will inline that
# composer too), the helper chain can be deleted entirely.
module Views::Controllers::Descriptions
  class List < Views::Base
    # `reviewer?` is description-domain only — it gates visibility
    # of restricted descriptions for users in the "reviewers" group.
    # Register here rather than on `Views::Base` so the helper stays
    # scoped to its actual consumer.
    register_value_helper :reviewer?

    prop :user, _Nilable(::User), default: nil
    prop :object, _Any
    prop :type, Symbol
    prop :current, _Nilable(_Any), default: nil
    # When the object has no visible descriptions, emit this text
    # instead. Callers pass the type-specific i18n message
    # (`:show_name_no_descriptions.t`, etc.) — pre-translated so the
    # view stays type-agnostic. Pass an html_safe string to embed
    # inline markup like an `indent` span.
    prop :empty_text, _Nilable(String), default: nil

    def view_template
      if visible_descriptions.any?
        visible_descriptions.each { |desc| div { render_item(desc) } }
      elsif @empty_text
        trusted_html(@empty_text.to_s)
      end
    end

    private

    def visible_descriptions
      @visible_descriptions ||=
        sort_descriptions(
          @object.descriptions.includes(:user).select { |d| visible?(d) }
        )
    end

    def visible?(desc)
      desc.notes? || (desc.user == @user) || reviewer? ||
        (desc.source_type == :public) || in_admin_mode?
    end

    def sort_descriptions(list)
      type_order = ::Description::ALL_SOURCE_TYPES
      list.sort_by do |desc|
        [
          (desc.id == @object.description_id ? 0 : 1),
          type_order.index(desc.source_type),
          -desc.note_status[0],
          -desc.note_status[1],
          description_title(desc),
          desc.id
        ]
      end
    end

    def render_item(desc)
      if desc == @current
        trusted_html(description_title(desc))
      else
        render_link(desc)
        render_mod_links(desc)
      end
    end

    def render_link(desc)
      # The pre-Phlex `description_link` helper had an
      # `return result if result.match?("(#{:private.t})$")` guard
      # meant to skip the link when the title ended in "(private)",
      # but Ruby's `String#match?` treats the bare `(` as a regex
      # group rather than a literal — the guard never fired in
      # practice. Don't reintroduce the (buggy) early return; always
      # render the link so behavior matches the pre-conversion view.
      a(href: url_for(desc.show_link_args),
        class: "description_link_#{desc.id}") do
        trusted_html(description_title(desc))
      end
    end

    def render_mod_links(desc)
      writer = writer?(desc)
      admin = admin?(desc)
      return unless writer || admin

      span(class: "ml-3") do
        plain("[ ")
        render_edit_link(desc) if writer
        plain(" | ") if writer && admin
        render_destroy_button(desc) if admin
        plain(" ]")
      end
    end

    def render_edit_link(desc)
      content, path, opts = ::Tab::Description::Edit.new(
        description: desc
      ).to_a
      render(Components::IconLink.new(content, path, **opts))
    end

    def render_destroy_button(desc)
      render(Components::CrudButton::Delete.new(target: desc, btn: nil))
    end

    # Wraps `Description#partial_format_name` with a rough-permissions
    # suffix ("(public)", "(restricted)", "(private)"). Returns a
    # `.t`-translated SafeBuffer so callers can `trusted_html` it.
    def description_title(desc)
      result = desc.partial_format_name
      permit = title_permission_label(desc)
      result += " (#{permit})" unless /(^| )#{permit}( |$)/i.match?(result)
      result.t
    end

    def title_permission_label(desc)
      if desc.parent.description_id == desc.id
        :default.l
      elsif desc.public
        :public.l
      elsif desc.is_reader?(@user)
        :restricted.l
      else
        :private.l
      end
    end

    def writer?(desc)
      desc.writer?(@user) || in_admin_mode?
    end

    def admin?(desc)
      desc.is_admin?(@user) || in_admin_mode?
    end
  end
end
