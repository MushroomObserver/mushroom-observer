# frozen_string_literal: true

module Tabs
  module CollectionNumbersHelper
    def collection_number_show_links(c_n:)
      return [] unless in_admin_mode? || c_n.can_edit?

      collection_number_mod_links(c_n)
    end

    def collection_numbers_index_links(obs:)
      [
        [:show_object.l(type: :observation),
         add_query_param(observation_path(obs)),
         { class: "observation_return_link" }],
        new_collection_number_for_obs_link(obs)
      ]
    end

    def collection_number_form_new_links(obs:)
      [collection_number_return_link(obs)]
    end

    def collection_number_form_edit_links(c_n:, back:, obj:)
      links = []
      links << if back == "index"
                 [:edit_collection_number_back_to_index.t,
                  add_query_param(c_n.index_link_args),
                  { class: "collection_numbers_index_link" }]
               else
                 collection_number_return_link(obj)
               end
    end

    def collection_number_return_link(obj)
      [:cancel_and_show.t(type: obj.type_tag),
       add_query_param(observation_path(obj)),
       { class: "#{obj.type_tag}_return_link" }]
    end

    def collection_number_mod_links(c_n)
      [edit_collection_number_link(c_n),
       destroy_collection_number_link(c_n)]
    end

    def new_collection_number_for_obs_link(obs)
      [:create_collection_number.l,
       add_query_param(new_collection_number_path(obs)),
       { class: "new_collection_number_link" }]
    end

    def edit_collection_number_link(c_n)
      [:edit_collection_number.t,
       add_query_param(edit_collection_number_path(id: c_n.id, back: :show)),
       { class: "edit_collection_number_link" }]
    end

    def destroy_collection_number_link(c_n)
      [:delete_collection_number.t, c_n,
       { button: :destroy, class: "destroy_collection_number_link" }]
    end
  end
end
