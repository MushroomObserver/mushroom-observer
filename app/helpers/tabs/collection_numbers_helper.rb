# frozen_string_literal: true

module Tabs
  module CollectionNumbersHelper
    def collection_number_show_links(c_n:)
      return [] unless in_admin_mode? || c_n.can_edit?

      collection_number_mod_links(c_n)
    end

    def collection_numbers_index_links(obs:)
      return [] if obs.blank?

      [
        object_return_link(obs),
        new_collection_number_for_obs_link(obs)
      ]
    end

    def collection_number_form_new_links(obs:)
      [object_return_link(obs)]
    end

    def collection_number_form_edit_links(c_n:, back:, obj:)
      links = []
      links << if back == "index"
                 collection_numbers_index_link(c_n)
               else
                 object_return_link(obj)
               end
    end

    def collection_numbers_index_link(c_n)
      [:edit_collection_number_back_to_index.t,
       add_query_param(c_n.index_link_args),
       { class: __method__.to_s }]
    end

    def collection_number_mod_links(c_n)
      [edit_collection_number_link(c_n),
       destroy_collection_number_link(c_n)]
    end

    def new_collection_number_for_obs_link(obs)
      [:create_collection_number.l,
       add_query_param(new_collection_number_path(obs)),
       { class: __method__.to_s }]
    end

    def edit_collection_number_link(c_n)
      [:edit_collection_number.t,
       add_query_param(edit_collection_number_path(id: c_n.id, back: :show)),
       { class: __method__.to_s }]
    end

    def destroy_collection_number_link(c_n)
      [:delete_collection_number.t, c_n, { button: :destroy }]
    end
  end
end
