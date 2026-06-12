# frozen_string_literal: true

# Past-version page for a `NameDescription`. Thin subclass of the
# shared `Views::Controllers::Descriptions::Versions::Show` base;
# only the per-type i18n key + context-nav tab + textile name
# registration are name-specific.
module Views::Controllers::Names::Descriptions::Versions
  class Show < ::Views::Controllers::Descriptions::Versions::Show
    prop :description, ::NameDescription
    prop :name, ::Name

    private

    def page_title_key
      :show_past_name_description_title
    end

    def version_actions
      ::Tab::NameDescription::VersionActions.new(
        description: @description, desc_title: desc_title
      )
    end

    def pre_render_setup
      ::Textile.register_name(@name)
    end
  end
end
