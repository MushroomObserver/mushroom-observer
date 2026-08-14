# frozen_string_literal: true

module Views::Controllers::Locations
  # New-location page wrapper — registers page-title / context-nav
  # chrome and delegates to the existing `Locations::Form`.
  class New < Views::FullPageBase
    prop :location, ::Location
    prop :display_name, _Nilable(::String), default: nil
    prop :original_name, _Nilable(::String), default: nil
    # All four come from params[...] (always a String, or absent) --
    # coerced to Integer so a non-numeric value fails loudly here
    # instead of round-tripping into the create-URL's query string.
    prop :set_observation, _Nilable(Integer), default: nil, &TO_ID
    prop :set_species_list, _Nilable(Integer), default: nil, &TO_ID
    prop :set_user, _Nilable(Integer), default: nil, &TO_ID
    prop :set_herbarium, _Nilable(Integer), default: nil, &TO_ID
    prop :set_project, _Nilable(Integer), default: nil, &TO_ID
    prop :dubious_where_reasons, _Nilable(_Array(_Tuple(Symbol, Hash))),
         default: nil
    def view_template
      container_class(:full)
      add_new_title(:create_object, :location)
      add_context_nav(::Tab::Location::FormNew.new(location: @location))

      render(Form.new(
               @location,
               display_name: @display_name,
               original_name: @original_name,
               set_observation: @set_observation,
               set_species_list: @set_species_list,
               set_user: @set_user,
               set_herbarium: @set_herbarium,
               set_project: @set_project,
               dubious_where_reasons: @dubious_where_reasons,
               local: false
             ))
    end
  end
end
