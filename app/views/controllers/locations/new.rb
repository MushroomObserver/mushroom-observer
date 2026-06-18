# frozen_string_literal: true

module Views::Controllers::Locations
  # New-location page wrapper — registers page-title / context-nav
  # chrome and delegates to the existing `Locations::Form`.
  class New < Views::FullPageBase
    prop :location, ::Location
    prop :display_name, _Nilable(::String), default: nil
    prop :original_name, _Nilable(::String), default: nil
    prop :set_observation,
         _Nilable(_Union(::String, ::Integer)), default: nil
    prop :set_species_list,
         _Nilable(_Union(::String, ::Integer)), default: nil
    prop :set_user,
         _Nilable(_Union(::String, ::Integer)), default: nil
    prop :set_herbarium,
         _Nilable(_Union(::String, ::Integer)), default: nil
    prop :dubious_where_reasons, _Nilable(_Array(::String)), default: nil
    def view_template
      container_class(:full)
      add_new_title(:create_object, :LOCATION)
      add_context_nav(::Tab::Location::FormNew.new(location: @location))

      render(Form.new(
               @location,
               display_name: @display_name,
               original_name: @original_name,
               set_observation: @set_observation,
               set_species_list: @set_species_list,
               set_user: @set_user,
               set_herbarium: @set_herbarium,
               dubious_where_reasons: @dubious_where_reasons
             ))
    end
  end
end
