# frozen_string_literal: true

# Custom View Helpers for Herbarium Records views
#
module Tabs
  module HerbariumRecordsHelper
    # link attribute arrays
    def herbarium_record_index_links
      links = []
      if params[:observation_id].present?
        links = [
          [:show_object.l(type: :observation),
           observation_path(params[:observation_id]),
           { id: "herbarium_observation_link" }],
          [:create_herbarium_record.l,
           new_herbarium_record_path(id: params[:id]),
           { id: "new_herbarium_record_link" }]
        ]
      end
      links << [:create_herbarium.l, new_herbarium_path,
                { id: "new_herbarium_link" }]
      links << [:herbarium_index.t, herbaria_path(flavor: :nonpersonal),
                { id: "all_nonpersonal_herbaria_link" }]
    end

    # HTML links because there's a destroy_button
    def herbarium_record_show_tabs(herbarium_record)
      tabs = []
      if in_admin_mode? || herbarium_record.can_edit?
        tabs << link_to(
          :edit_herbarium_record.t,
          edit_herbarium_record_path(id: herbarium_record.id,
                                     back: :show, q: get_query_param),
          id: "edit_herbarium_record_link"
        )
        tabs << destroy_button(
          name: :destroy_object.t(type: :herbarium_record),
          target: herbarium_record_path(herbarium_record.id),
          id: "destroy_herbarium_record_link"
        )
      end
      tabs << link_to(:herbarium_index.t, herbaria_path(flavor: :nonpersonal),
                      id: "herbarium_index_link")
      tabs
    end

    # link attribute arrays
    def herbarium_record_form_new_links(observation)
      [
        [:cancel_and_show.t(type: :observation),
         add_query_param(observation_path(observation.id)),
         { id: "show_observation_link" }],
        [:create_herbarium.t,
         add_query_param(new_herbarium_path),
         { id: "new_herbarium_link" }],
        [:herbarium_index.t,
         add_query_param(herbaria_path(flavor: :nonpersonal)),
         { id: "all_nonpersonal_herbaria_link" }]
      ]
    end

    # link attribute arrays
    def herbarium_record_form_edit_links(back, back_object)
      links = []
      if back == "index"
        links << [:edit_herbarium_record_back_to_index.t,
                  herbarium_records_path(q: get_query_param),
                  { id: "herbarium_records_link" }]
      elsif back_object&.type_tag == :observation
        links << [:cancel_and_show.t(type: back_object.type_tag),
                  observation_path(id: back_object.id,
                                   q: get_query_param),
                  { id: "herbarium_record_observation_link" }]
      elsif back_object&.type_tag == :herbarium_record
        links << [:cancel_and_show.t(type: back_object.type_tag),
                  herbarium_record_path(id: back_object.id,
                                        q: get_query_param),
                  { id: "herbarium_record_link" }]
      end
      links << [:create_herbarium.t,
                new_herbarium_path(q: get_query_param),
                { id: "new_herbarium_link" }]
      links << [:herbarium_index.t,
                herbaria_path(flavor: :nonpersonal),
                { id: "all_nonpersonal_herbaria_link" }]
    end
  end
end
