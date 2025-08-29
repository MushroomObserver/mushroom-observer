# frozen_string_literal: true

# Custom View Helpers for Herbarium Records views
#
module Tabs
  module HerbariumRecordsHelper
    include HerbariaHelper

    def herbarium_records_index_tabs(obs:)
      links = []
      if obs.present?
        links = [
          object_return_tab(obs)
        ]
      end
      links << new_herbarium_tab
      links << nonpersonal_herbaria_index_tab
    end

    def herbarium_records_index_sorts
      [
        ["herbarium_name",    :sort_by_herbarium_name.t],
        ["herbarium_label",   :sort_by_herbarium_label.t],
        ["initial_det",       :sort_by_initial_det.t],
        ["accession_number",  :sort_by_accession_number.t],
        ["created_at",        :sort_by_created_at.t],
        ["updated_at",        :sort_by_updated_at.t]
      ].freeze
    end

    def herbarium_record_show_tabs
      [nonpersonal_herbaria_index_tab]
    end

    def herbarium_record_form_new_tabs(obs:)
      [
        object_return_tab(obs),
        new_herbarium_tab,
        nonpersonal_herbaria_index_tab
      ]
    end

    def herbarium_record_form_edit_tabs(back:, back_object:)
      links = []
      if back == "index"
        links << herbarium_records_index_return_tab
      elsif back_object
        links << object_return_tab(back_object)
      end
      links << new_herbarium_tab
      links << nonpersonal_herbaria_index_tab
    end

    def herbarium_record_tab(h_r, obs)
      # This is passed in to show_herbarium_record, allowing users to do prev,
      # next and index from there to navigate through all the rest for this obs.
      hr_query = Query.lookup(:HerbariumRecord, observations: obs.id)

      InternalLink::Model.new(
        h_r.accession_at_herbarium.t, h_r,
        add_q_param(h_r.show_link_args, hr_query),
        alt_title: "herbarium_record"
      ).tab
    end

    def new_herbarium_record_tab(obs)
      InternalLink::Model.new(
        :create_herbarium_record.l, Herbarium,
        new_herbarium_record_path(observation_id: obs.id),
        html_options: { icon: :add }
      ).tab
    end

    def edit_herbarium_record_tab(h_r, obs = nil)
      back = obs&.id || :show
      InternalLink::Model.new(
        :edit_herbarium_record.t, h_r,
        edit_herbarium_record_path(h_r.id, back: back),
        html_options: { icon: :edit }
      ).tab
    end

    def herbarium_records_index_return_tab
      InternalLink.new(
        :edit_herbarium_record_back_to_index.t,
        herbarium_records_path(q: q_param)
      ).tab
    end

    def remove_herbarium_record_tab(h_r, obs)
      url = edit_herbarium_record_remove_observation_path(
        herbarium_record_id: h_r.id, observation_id: obs.id
      )
      InternalLink::Model.new(:REMOVE.t, h_r, url,
                              html_options: { icon: :remove }).tab
    end
  end
end
