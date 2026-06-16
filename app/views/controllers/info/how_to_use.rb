# frozen_string_literal: true

module Views::Controllers::Info
  # How-to-use guide — two numbered lists (common tasks + glossary).
  class HowToUse < Views::Base
    # rubocop:disable Layout/HashAlignment
    COMMON_TASKS = {
      keeping_up:             :how_keeping_up,
      searching:              :how_searching,
      unknown_help:           :how_unknown_help,
      adding_observations:    :how_adding_observations,
      proposing_names:        :how_proposing_names,
      voting:                 :how_voting,
      adding_comments:        :how_adding_comments,
      tracking_species:       :how_tracking_species,
      describing_species:     :how_describing_species,
      projects:               :how_projects,
      maps:                   :how_maps,
      defining_locations:     :how_defining_locations,
      creating_species_lists: :how_creating_species_lists,
      write_in_observations:  :how_write_in
    }.freeze

    GLOSSARY = {
      comment:       :how_comment,
      image:         :how_image,
      license:       :how_license,
      location:      :how_location,
      name:          :how_name,
      observation:   :how_observation,
      proposed_name: :how_proposed_name,
      species_list:  :how_species_list,
      user:          :how_user,
      vote:          :how_vote
    }.freeze
    # rubocop:enable Layout/HashAlignment

    prop :min_pos_vote, ::String
    prop :min_neg_vote, ::String
    prop :maximum_vote, ::String

    def view_template
      add_page_title(:how_title.l)
      trusted_html(:how_intro.tp)

      h4 { "#{:how_common_tasks.l}:" }
      render_ordered_list(COMMON_TASKS)

      h4 { "#{:how_glossary.l}:" }
      render_ordered_list(GLOSSARY)
    end

    private

    def render_ordered_list(items)
      ol do
        items.each do |anchor, key|
          li(id: anchor.to_s) { trusted_html(rendered(key)) }
        end
      end
    end

    def rendered(key)
      case key
      when :how_voting, :how_vote
        key.tp(min_pos_vote: @min_pos_vote, min_neg_vote: @min_neg_vote,
               max_vote: @maximum_vote, no_opinion: :vote_no_opinion.l)
      else
        key.tp
      end
    end
  end
end
