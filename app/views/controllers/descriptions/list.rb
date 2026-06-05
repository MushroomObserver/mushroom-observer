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
# composed. Both helper files have since been deleted (this view + the
# sibling `DetailsAndAltsPanel` own every chain they used to compose).
module Views::Controllers::Descriptions
  class List < Views::Base
    # `reviewer?` is description-domain only — it gates visibility
    # of restricted descriptions for users in the "reviewers" group.
    # Register here rather than on `Views::Base` so the helper stays
    # scoped to its actual consumer.
    register_value_helper :reviewer?

    prop :user, _Nilable(::User), default: nil
    prop :object, _Union(::Name, ::Location)
    prop :type, _Union(:name, :location)
    prop :current, _Nilable(::Description), default: nil
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
      if desc == @current || !reader?(desc)
        # Render plain text (no `<a>`) when:
        # - We're already on `desc`'s show page (no self-link).
        # - The user isn't a reader of `desc` — they'd just bounce
        #   off the show controller's read check with a flash
        #   error, so don't offer a misleading clickable link.
        #   The pre-Phlex `description_link` helper *tried* to do
        #   the non-reader half with
        #   `result.match?("(#{:private.t})$")`, but the title
        #   was always wrapped in a `translation_missing` span
        #   (see `description_title`) so the literal "(private)"
        #   suffix never matched and the guard never fired. We're
        #   honoring the original intent here.
        trusted_html(description_title(desc))
      else
        render_link(desc)
        render(Components::InlineModLinks.new(target: desc, user: @user))
      end
    end

    def render_link(desc)
      a(href: url_for(desc.show_link_args),
        class: "description_link_#{desc.id}") do
        trusted_html(description_title(desc))
      end
    end

    # Wraps `Description#partial_format_name` with a rough-permissions
    # suffix ("(public)", "(restricted)", "(private)"). Returns a
    # textile-processed SafeBuffer so callers can `trusted_html` it.
    #
    # Pre-Phlex this method called Rails' helper `t(result)` on a
    # free-text string, which always hit `I18n.t` as a missing
    # translation and wrapped the title in
    # `<span class="translation_missing">…</span>` with title-cased
    # fallback ("Eol Project (Restricted)"). That span shipped to
    # every show-name / show-location page with an alt description.
    # `String#t` (textile, MO's `app/extensions/string.rb#t`) is what
    # this method was always meant to call — it does textile
    # processing without the missing-translation wrapper.
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
      elsif reader?(desc)
        :restricted.l
      else
        :private.l
      end
    end

    # `reader?` falls back to `in_admin_mode?` so admins see
    # drafts as "restricted" (not "private") and can click
    # through. Edit / destroy permissions are owned by
    # `Components::InlineModLinks` (`writer?` / `is_admin?`
    # branches there).
    def reader?(desc)
      desc.is_reader?(@user) || in_admin_mode?
    end
  end
end
