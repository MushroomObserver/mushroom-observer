# frozen_string_literal: true

module Tabs
  module SequencesHelper
    def sequence_show_tabs(seq:)
      links = [
        link_to(:cancel_and_show.t(type: :observation),
                seq.observation.show_link_args)
      ]
      return unless check_permission(seq)

      links += sequence_mod_tabs(seq)
      links
    end

    def sequence_form_new_title
      :sequence_add_title.t
    end

    def sequence_form_edit_title(seq:)
      :sequence_edit_title.t(name: seq.unique_format_name)
    end

    def sequence_form_tabs(obj:)
      [object_return_tab(obj)]
    end

    def show_sequence_tab(seq, obs)
      # This is passed in to show_sequence, allowing users to do prev,
      # next and index from there to navigate through all the rest for this obs.
      sq_query = Query.lookup(:Sequence, :all, observations: obs.id)
      locus = seq.locus.truncate(seq.locus_width)
      txt = if seq.deposit?
              "#{locus} - #{seq.archive} ##{seq.accession}"
            else
              "#{locus} - MO ##{seq.id}"
            end

      [txt.t, add_query_param(seq.show_link_args, sq_query),
       { class: "#{tab_id(__method__.to_s)}_#{seq.id}" }]
    end

    def sequence_archive_tab(seq)
      [:show_observation_archive_link.t, seq.accession_url,
       { class: "#{tab_id(__method__.to_s)}_#{seq.id}", target: "_blank" }]
    end

    def sequence_blast_tab(seq)
      [:show_observation_blast_link.t, seq.blast_url,
       { class: "#{tab_id(__method__.to_s)}_#{seq.id}", target: "_blank" }]
    end

    def sequence_mod_tabs(seq)
      [edit_sequence_and_back_tab(seq),
       destroy_sequence_tab(seq)]
    end

    def edit_sequence_and_back_tab(seq)
      [:edit_object.t(type: :sequence),
       seq.edit_link_args.merge(back: :show),
       { class: "edit_sequence_link" }]
    end

    def edit_sequence_tab(seq, obs)
      [:EDIT.t,
       edit_sequence_path(id: seq.id, back: obs.id, q: get_query_param),
       { class: "#{tab_id(__method__.to_s)}_#{seq.id}", icon: :edit }]
    end

    def new_sequence_tab(obs)
      [:show_observation_add_sequence.t,
       new_sequence_path(observation_id: obs.id, q: get_query_param),
       { class: tab_id(__method__.to_s), icon: :add }]
    end

    def destroy_sequence_tab(seq)
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
