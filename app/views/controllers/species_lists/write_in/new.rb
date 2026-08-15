# frozen_string_literal: true

module Views::Controllers::SpeciesLists::WriteIn
  # Action view for the species_list write-in `new` page (also
  # re-rendered by the `create` action on validation failure).
  # Sets the page chrome and delegates to the Phlex `Form`.
  class New < Views::FullPageBase
    prop :species_list, ::SpeciesList
    prop :user, ::User
    prop :button, Symbol
    # new_names/deprecated_names/multiple_names/list_members/place_name
    # only get set on the create action's validation-failure re-render
    # (init_name_vars_from_sorter) -- the initial #new GET never
    # touches them, so they're nil there.
    prop :new_names, _Nilable(_Array(String))
    prop :deprecated_names, _Nilable(_Array(::Name))
    prop :multiple_names, _Nilable(_Array(_Tuple(::Name, _Array(::Name))))
    prop :dubious_where_reasons, _Nilable(_Array(_Tuple(Symbol, Hash)))
    prop :list_members, _Nilable(String)
    prop :place_name, _Nilable(String)
    prop :member_vote, _Union(Integer, String)
    prop :member_notes, ::NotesHash
    prop :member_notes_parts, _Array(String)
    prop :member_lat, _Nilable(String)
    prop :member_lng, _Nilable(String)
    prop :member_alt, _Nilable(String)
    prop :member_is_collection_location, _Boolean
    prop :member_specimen, _Boolean

    def view_template
      add_page_title(
        :species_list_write_in_title.t(list_title: @species_list.title)
      )
      add_context_nav(::Tab::SpeciesList::FormWriteIn.new(list: @species_list))
      container_class(:text)

      render(Form.new(@species_list,
                      user: @user,
                      button: @button,
                      new_names: @new_names,
                      deprecated_names: @deprecated_names,
                      multiple_names: @multiple_names,
                      dubious_where_reasons: @dubious_where_reasons,
                      list_members: @list_members,
                      place_name: @place_name,
                      member_vote: @member_vote,
                      member_notes: @member_notes,
                      member_notes_parts: @member_notes_parts,
                      member_lat: @member_lat,
                      member_lng: @member_lng,
                      member_alt: @member_alt,
                      member_is_collection_location:
                        @member_is_collection_location,
                      member_specimen: @member_specimen,
                      local: false))
    end
  end
end
