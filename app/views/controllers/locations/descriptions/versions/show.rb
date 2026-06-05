# frozen_string_literal: true

# Past-version page for a `LocationDescription`. Thin subclass of
# the shared `Views::Controllers::Descriptions::Versions::Show`
# base; only the per-type i18n key + context-nav tab differ.
module Views::Controllers::Locations::Descriptions::Versions
  class Show < ::Views::Controllers::Descriptions::Versions::Show
    prop :description, ::LocationDescription

    private

    def page_title_key
      :show_past_location_description_title
    end

    def version_actions
      ::Tab::LocationDescription::VersionActions.new(
        description: @description, desc_title: desc_title
      )
    end
  end
end
