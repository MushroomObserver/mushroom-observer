# frozen_string_literal: true

# Species lists list/manage table -- one row per SpeciesList, as a
# Components::Table with two columns: info (title/place/user) and
# action (REMOVE/ADD button or an observation count badge). Used by
# `SpeciesLists::Index` and, via `Components::ObservationListManager`,
# by `Observations::SpeciesLists::Edit`.
module Views::Controllers::SpeciesLists
  class SpeciesListTable < Views::Base
    prop :objects, _Array(::SpeciesList), :positional
    prop :observation, _Nilable(::Observation), default: nil
    prop :remove, _Boolean, default: false
    prop :add, _Boolean, default: false
    prop :project, _Nilable(::Project), default: nil
    prop :observation_counts, _Hash(Integer, Integer), default: -> { {} }
    # Which rows get a REMOVE/ADD button, keyed by id -- the caller
    # resolves `permission?` (needs an auth context) before this
    # renders. `nil` means every row qualifies.
    prop :manageable_ids, _Nilable(_Array(Integer)), default: nil

    def view_template
      Table(@objects, variant: :lg) do |t|
        t.column(:species_list.ti) { |list| render_info_cell(list) }
        t.column(:observations.ti, align: :right) do |list|
          render_action_cell(list)
        end
      end
    end

    private

    def render_info_cell(species_list)
      render_title_row(species_list)
      render_place_user_row(species_list)
    end

    def render_title_row(species_list)
      div(class: "d-flex align-items-center") do
        Link(type: :get, name: species_list.text_name.t,
             target: species_list.show_link_with_project(@project)) do
          span(class: "list_what h4") do
            trusted_html(species_list.text_name.t)
          end
        end
        IDBadge(object: species_list, size: :xl, extra_class: "ml-3")
      end
    end

    def render_place_user_row(species_list)
      div do
        span { trusted_html(place_for(species_list)) }
        whitespace
        plain("|")
        whitespace
        trusted_html(append_colon(species_list.when))
        whitespace
        Link(type: :user, user: species_list.user)
      end
    end

    # `place_name.t` can blow up on lists without a place -
    # `rescue :unknown.ti` is fallback.
    def place_for(species_list)
      species_list.place_name(current_user).t
    rescue StandardError
      :unknown.ti
    end

    def render_action_cell(species_list)
      if @remove || @add
        render_manage_section(species_list) if manageable?(species_list)
      else
        CountBadge(count: @observation_counts[species_list.id].to_i)
      end
    end

    def manageable?(species_list)
      @manageable_ids.nil? || @manageable_ids.include?(species_list.id)
    end

    def render_manage_section(species_list)
      if @remove
        render_remove_obs_button(species_list)
      elsif @add
        render_add_obs_button(species_list)
      end
    end

    def render_remove_obs_button(species_list)
      Button(
        type: :delete,
        variant: :outline,
        icon: :remove,
        name: :remove.ti,
        show_label: :responsive,
        target: observation_species_list_path(
          id: @observation.id,
          species_list_id: species_list.id
        ),
        confirm: :are_you_sure.l
      )
    end

    def render_add_obs_button(species_list)
      Button(
        type: :put,
        name: :add.ti,
        icon: :attach,
        show_label: :responsive,
        target: observation_species_list_path(
          id: @observation.id,
          species_list_id: species_list.id
        )
      )
    end
  end
end
