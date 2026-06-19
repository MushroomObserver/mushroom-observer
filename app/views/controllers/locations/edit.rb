# frozen_string_literal: true

module Views::Controllers::Locations
  # Edit page wrapper — renders the existing `Locations::Form` after
  # registering page-title / context-nav chrome.
  class Edit < Views::FullPageBase
    prop :location, ::Location
    prop :display_name, _Nilable(::String), default: nil
    prop :dubious_where_reasons, _Nilable(_Array(::String)), default: nil

    def view_template
      add_edit_title(@location)
      add_context_nav(::Tab::Location::FormEdit.new(location: @location))
      container_class(:full)

      render(Form.new(
               @location,
               display_name: @display_name,
               dubious_where_reasons: @dubious_where_reasons
             ))
    end
  end
end
