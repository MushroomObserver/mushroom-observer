# frozen_string_literal: true

# Custom View Helpers for Herbarium Records views
#
module Tabs
  module HerbariumRecordsHelper
    include HerbariaHelper
    def herbarium_record_index_links
      links = []
      if params[:observation_id].present?
        links = [
          [:show_object.l(type: :observation),
           observation_path(params[:observation_id]),
           { class: "observation_link" }],
          [:create_herbarium_record.l,
           new_herbarium_record_path(id: params[:id]),
           { class: "new_herbarium_record_link" }]
        ]
      end
      links << [:create_herbarium.l, new_herbarium_path,
                { class: "new_herbarium_link" }]
      links << [:herbarium_index.t, herbaria_path(flavor: :nonpersonal),
                { class: "nonpersonal_herbaria_index_link" }]
    end

    def herbarium_record_show_links(herbarium_record:)
      links = []
      if in_admin_mode? || herbarium_record.can_edit?
        links.push(
          [:edit_herbarium_record.t,
           edit_herbarium_record_path(id: herbarium_record.id,
                                      back: :show, q: get_query_param),
           { class: "edit_herbarium_record_link" }],
          [:destroy_object.t(type: :herbarium_record),
           herbarium_record, { button: :destroy }]
        )
      end
      links << nonpersonal_herbaria_index_link_unlabeled
      links
    end

    def herbarium_record_form_new_links(observation:)
      [
        [:cancel_and_show.t(type: :observation),
         add_query_param(observation_path(observation.id)),
         { class: "observation_link" }],
        [:create_herbarium.t,
         add_query_param(new_herbarium_path),
         { class: "new_herbarium_link" }],
        nonpersonal_herbaria_index_link_unlabeled
      ]
    end

    def herbarium_record_form_edit_links(back:, back_object:)
      links = []
      if back == "index"
        links << [:edit_herbarium_record_back_to_index.t,
                  herbarium_records_path(q: get_query_param),
                  { class: "herbarium_records_index_link" }]
      elsif back_object&.type_tag == :observation
        links << [:cancel_and_show.t(type: back_object.type_tag),
                  observation_path(id: back_object.id,
                                   q: get_query_param),
                  { class: "observation_link" }]
      elsif back_object&.type_tag == :herbarium_record
        links << [:cancel_and_show.t(type: back_object.type_tag),
                  herbarium_record_path(id: back_object.id,
                                        q: get_query_param),
                  { class: "herbarium_record_link" }]
      end
      links << [:create_herbarium.t,
                new_herbarium_path(q: get_query_param),
                { class: "new_herbarium_link" }]
      links << nonpersonal_herbaria_index_link_unlabeled
    end
  end
end
