# frozen_string_literal: true

module Tabs
  module SequencesHelper
    def sequence_show_links(seq:)
      links = [
        link_to(:cancel_and_show.t(type: :observation),
                seq.observation.show_link_args)
      ]
      return unless check_permission(seq)

      links += sequence_mod_links(seq)
      links
    end

    def sequence_form_links(obj:)
      [
        [:cancel_and_show.t(type: obj.type_tag),
         add_query_param(obj.show_link_args),
         { class: "observation_return_link" }]
      ]
    end

    def sequence_mod_links(seq)
      [
        [:edit_object.t(type: :sequence),
         seq.edit_link_args.merge(back: :show),
         { class: "edit_sequence_link" }],
        [:destroy_object.t(type: :sequence),
         sequence_path(seq, back: url_after_delete(seq)),
         { button: :destroy, class: "destroy_sequence_link" }]
      ]
    end
  end
end
