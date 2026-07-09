# frozen_string_literal: true

module Views::Controllers::Sequences
  # Sequence detail — obs link, locus, optional BASES, optional
  # deposit (archive + accession), BLAST link, notes, creator.
  # Rendered as a `ContentPadded` block; no panel chrome.
  class Show < Views::FullPageBase
    prop :sequence, ::Sequence

    def view_template
      register_chrome
      ContentPadded(class: "container-text") do
        render_fields
      end
      render(::Views::Layouts::ObjectFooter.new(
               user: current_user, obj: @sequence
             ))
    end

    def render_fields
      render_obs_line
      render_locus
      render_bases if @sequence.bases.present?
      render_deposit if @sequence.deposit?
      render_blast_link
      return if @sequence.notes.blank?

      render_field(:NOTES, -> { trusted_html(@sequence.notes.tp) })
    end

    private

    def register_chrome
      add_show_title(@sequence)
      add_edit_icons(@sequence, current_user) if current_user
      add_pager_for(@sequence)
      add_context_nav(::Tab::Sequence::ShowActions.new(sequence: @sequence))
      container_class(:wide)
      # Title + pager share the title-bar row only when the layout
      # gets column widths from `column_classes`; without this, both
      # render full-width and stack.
      column_classes(:eight_four)
    end

    def render_obs_line
      obs = @sequence.observation
      p do
        strong { "#{:OBSERVATION.l}:" }
        whitespace
        link_to(obs.show_link_args) do
          trusted_html(obs.name.display_name(current_user).t)
        end
        plain(" (#{obs.id})")
      end
    end

    def render_field(label_key, value)
      p do
        strong { "#{label_key.l}:" }
        whitespace
        value.is_a?(::Proc) ? value.call : plain(value.to_s)
      end
    end

    # `<pre>` isn't permitted as a `<p>` descendant in HTML5 (the
    # parser auto-closes the open `<p>` on encountering `<pre>`),
    # so the locus line uses a `<div>` wrapper instead.
    def render_locus
      div(class: "mb-3") do
        strong { "#{:LOCUS.l}:" }
        whitespace
        pre(class: "d-inline text-monospace") { plain(@sequence.locus) }
      end
    end

    def render_bases
      p do
        strong { "#{:BASES.l}:" }
        whitespace
        render(::Components::Button::Clipboard.new(
                 text: @sequence.bases, name: :COPY_THIS_SEQUENCE.l,
                 class: "ml-1"
               ))
      end
      pre(class: "text-monospace",
          style: "white-space: pre-wrap; word-break: break-all") do
        plain(@sequence.bases)
      end
    end

    def render_deposit
      p do
        strong { "#{:DEPOSIT.l}:" }
        whitespace
        render_archive_link
        plain(": ")
        render_accession_link
      end
    end

    # MycoBLAST has no query param to pre-fill (unlike NCBI), so
    # it's just a plain link to the tool rather than a per-Sequence
    # report — shown unconditionally, same as the NCBI button.
    def render_blast_link
      blast_tab = ::Tab::Sequence::Blast.new(sequence: @sequence)
      p do
        Button(type: :external,
               name: blast_tab.title,
               url: blast_tab.path)
        whitespace
        Button(
          type: :external,
          name: :show_observation_mycoblast_link.l,
          url: ::Sequence.mycoblast_url
        )
      end
    end

    def render_archive_link
      Link(type: :external,
           tab: ::Tab::Sequence::Archive.new(sequence: @sequence))
    end

    def render_accession_link
      Link(type: :external,
           content: truncate(@sequence.accession,
                             length: @sequence.locus_width / 2).t,
           path: @sequence.accession_url)
    end
  end
end
