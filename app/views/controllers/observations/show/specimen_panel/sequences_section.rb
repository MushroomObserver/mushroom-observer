# frozen_string_literal: true

# DNA-sequences section of the Specimen panel. Same list-row shape
# as the other Specimen sections but with an additional archive
# inline link when the sequence has a deposit accession URL.
#
# `Components::InlineCRUDLinks` handles the archive/edit/destroy
# group — sequences are a real-DELETE target with a
# `back: permanent_observation_path(obs)` query string so the controller
# redirects to the obs after destroy.
class Views::Controllers::Observations::Show::SpecimenPanel
  class SequencesSection < Views::Base
    include Views::Controllers::Observations::Show::OccurrenceStatusIcons

    prop :obs, ::Observation
    prop :user, _Nilable(::User), default: nil
    prop :has_sibling_records, _Boolean, default: false

    def view_template
      div(
        id: "observation_sequences",
        class: "obs-sequence",
        data: { controller: "section-update",
                section_update_user_value: @user&.id }
      ) do
        render_header if @user || sequences.any?
        render_list if sequences.any?
      end
    end

    private

    # A sequence describes the specimen, and the occurrence is the
    # specimen-level grouping -- a reflection's native sequences live
    # on its companion (see SequencesController::ReflectionRouting) --
    # so the panel lists the whole occurrence's sequences. Each row
    # keeps its member observation for the status icons.
    def sequence_rows
      @sequence_rows ||=
        if @obs.occurrence
          @obs.occurrence.observations.flat_map do |member|
            member.sequences.map { |seq| [seq, member] }
          end
        else
          @obs.sequences.map { |seq| [seq, @obs] }
        end
    end

    def sequences
      sequence_rows.map(&:first)
    end

    def render_header
      div do
        plain(header_label)
        render_new_link if @user
      end
    end

    def header_label
      if sequences.any? || @has_sibling_records
        append_colon(:sequences.ti)
      else
        "#{:no_objects.t(type: :sequence)} "
      end
    end

    def render_new_link
      InlineCRUDLinks(
        modal_id: "sequence",
        tab: ::Tab::Sequence::New.new(observation: @obs)
      )
    end

    def render_list
      ul(class: "tight-list") do
        sequence_rows.each { |seq, member| render_row(seq, member) }
      end
    end

    # Same star/lock member-status icons as the Matching Observations
    # panel, so a rolled-up sequence shows whose record it sits on.
    def render_row(sequence, member)
      li(id: "sequence_#{sequence.id}") do
        icon_types = member_status_icon_types(member, @obs.occurrence)
        render_status_icons(icon_types)
        span(class: ("icon-text-gap" if icon_types.any?)) do
          render_show_link(sequence)
        end
        InlineCRUDLinks(
          target: sequence, user: @user,
          extras: [archive_link(sequence), copy_link(sequence)].compact
        )
      end
    end

    def render_show_link(sequence)
      content, path, opts = ::Tab::Sequence::Show.new(
        sequence: sequence, observation: @obs
      ).to_a
      a(href: url_for(path), **opts) { trusted_html(content) }
    end

    def archive_link(sequence)
      return nil unless sequence.deposit?

      content, path, opts = ::Tab::Sequence::Archive.new(
        sequence: sequence
      ).to_a
      opts = opts.merge(
        class: Components::InlineLinkBlock.item_class(opts[:class])
      )
      # Wrap in a bare `<a>` and capture so it composes into
      # InlineCRUDLinks' `extras:` slot list. `capture` returns a
      # SafeBuffer in Phlex 2.x — no extra `.html_safe` needed.
      capture { a(href: url_for(path), **opts) { trusted_html(content) } }
    end

    # Bases aren't displayed in this row (only the truncated locus
    # is), so the copy button copies straight from the model rather
    # than from rendered text on the page.
    def copy_link(sequence)
      return nil if sequence.bases.blank?

      Components::Button::Clipboard.new(
        text: sequence.bases, name: :copy_this_sequence.ti,
        class: Components::InlineLinkBlock.item_class
      )
    end
  end
end
