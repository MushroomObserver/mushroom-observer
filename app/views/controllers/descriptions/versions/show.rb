# frozen_string_literal: true

# Shared base view for the past-version pages of name and location
# descriptions. Both subclasses share the same shape:
#
#   - Page title built from a per-type i18n key + a textile-processed
#     `desc_title` (the partial format name with a rough-permissions
#     suffix).
#   - Per-type `VersionActions` context-nav.
#   - The shared past-versions table.
#   - The same `DetailsAndAltsPanel` and `VersionsFooter` the regular
#     description show page uses.
#
# Subclasses provide:
#
#   - `page_title_key`: the `:show_past_<type>_description_title`
#     symbol passed to the page title.
#   - `version_actions`: the per-type `Tab::*Description::VersionActions`
#     PORO instance.
#   - Any extra setup (e.g. `Textile.register_name`) via a
#     `pre_render_setup` hook.
module Views::Controllers::Descriptions::Versions
  class Show < Views::Base
    prop :description, ::Description
    prop :user, _Nilable(::User), default: nil
    prop :versions, _Array(_Interface(:user_id))
    prop :projects, _Nilable(_Array(::Project)), default: nil

    def view_template
      add_page_title(page_title_key.t(num: @description.version,
                                      name: desc_title))
      add_context_nav(version_actions)
      pre_render_setup

      render(Views::Controllers::Versions::Table.new(
               obj: @description, versions: @versions
             ))
      render(Views::Controllers::Descriptions::DetailsAndAltsPanel.new(
               description: @description, user: @user,
               versions: @versions, projects: @projects
             ))
      render(Views::Layouts::VersionsFooter.new(
               user: @user, obj: @description, versions: @versions
             ))
    end

    private

    # Subclass extension points -----------------------------------

    def page_title_key
      raise(NotImplementedError.new(
              "Subclass must implement page_title_key"
            ))
    end

    def version_actions
      raise(NotImplementedError.new(
              "Subclass must implement version_actions"
            ))
    end

    # Hook for any per-type setup that has to run before the body
    # renders. Default no-op; the name-description subclass uses
    # this to `Textile.register_name(@name)`.
    def pre_render_setup; end

    # Shared helpers ----------------------------------------------

    # Textile-processed partial title with rough-permissions suffix
    # ("(default)" / "(public)" / "(restricted)" / "(private)").
    # Mirrors `DetailsAndAltsPanel#description_title` — the same
    # logic as the alt-descriptions list.
    def desc_title
      @desc_title ||=
        begin
          result = @description.partial_format_name
          permit = title_permission_label
          result += " (#{permit})" unless
            /(^| )#{permit}( |$)/i.match?(result)
          result.t
        end
    end

    def title_permission_label
      if @description.parent.description_id == @description.id
        :default.l
      elsif @description.public
        :public.l
      elsif @description.is_reader?(@user) || in_admin_mode?
        :restricted.l
      else
        :private.l
      end
    end
  end
end
