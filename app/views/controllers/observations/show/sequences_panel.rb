# frozen_string_literal: true

# DNA-sequences sub-panel. Same list-row shape as the other
# obs-show sub-panels but with an additional `[archive]` inline
# link when the sequence has a deposit accession URL.
#
# `Components::Link::InlineMod` handles
# the `[ archive | edit | destroy ]` triplet — sequences are a
# real-DELETE target with a `back: observation_path(obs)` query
# string so the controller returns to the obs after destroy.
class Views::Controllers::Observations::Show::SequencesPanel < Views::Base
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

  def sequences
    @sequences ||= @obs.sequences
  end

  def render_header
    div do
      plain(header_label)
      render_new_link if @user
    end
  end

  def header_label
    if sequences.any? || @has_sibling_records
      "#{:show_observation_dna_sequences.l}: "
    else
      "#{:show_observation_no_sequences.l} "
    end
  end

  def render_new_link
    Link(type: :inline_add,
         modal_id: "sequence",
         tab: ::Tab::Sequence::New.new(observation: @obs))
  end

  def render_list
    ul(class: "tight-list") do
      sequences.each { |seq| render_row(seq) }
    end
  end

  def render_row(sequence)
    li(id: "sequence_#{sequence.id}") do
      render_show_link(sequence)
      Link(type: :inline_mod,
           target: sequence, observation: @obs, user: @user,
           extras: [archive_link(sequence), copy_link(sequence)].compact)
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
    # Wrap in a bare `<a>` and capture so it composes into the
    # InlineModLinks `[ extras | edit | destroy ]` slot list.
    # `capture` returns a SafeBuffer in Phlex 2.x — no extra
    # `.html_safe` needed.
    capture { a(href: url_for(path), **opts) { trusted_html(content) } }
  end

  # Bases aren't displayed in this row (only the truncated locus
  # is), so the copy button copies straight from the model rather
  # than from rendered text on the page.
  def copy_link(sequence)
    return nil if sequence.bases.blank?

    Components::Button::Clipboard.new(
      text: sequence.bases, name: :COPY_THIS_SEQUENCE.l
    )
  end
end
