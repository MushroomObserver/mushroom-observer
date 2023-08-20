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
      [object_return_link(obj)]
    end

    def sequence_mod_links(seq)
      [edit_sequence_link(seq),
       destroy_sequence_link(seq)]
    end

    def edit_sequence_link(seq)
      [:edit_object.t(type: :sequence),
       seq.edit_link_args.merge(back: :show),
       { class: __method__.to_s }]
    end

    def destroy_sequence_link(seq)
      [:destroy_object.t(type: :sequence), seq,
       { button: :destroy, back: url_after_delete(seq) }]
    end

    def sequences_index_sorts
      [
        ["created_at",  :sort_by_created_at.t],
        ["updated_at",  :sort_by_updated_at.t],
        ["user",        :USER.t],
        ["observation", :OBSERVATION.t]
      ].freeze
    end
  end
end
