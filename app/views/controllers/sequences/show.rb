# frozen_string_literal: true

module Views::Controllers::Sequences
  # Sequence detail — obs link, locus, optional BASES, optional
  # deposit (archive + accession), BLAST link, notes, creator.
  # Rendered as a `ContentPadded` block; no panel chrome.
  class Show < Views::Base
    prop :sequence, ::Sequence

    def view_template
      register_chrome
      render(::Components::ContentPadded.new(class: "container-text")) do
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
        plain(" ")
        link_to(obs.show_link_args) do
          trusted_html(obs.name.display_name.t)
        end
        plain(" (#{obs.id})")
      end
    end

    def render_field(label_key, value)
      p do
        strong { "#{label_key.l}:" }
        plain(" ")
        value.is_a?(::Proc) ? value.call : plain(value.to_s)
      end
    end

    # `<pre>` isn't permitted as a `<p>` descendant in HTML5 (the
    # parser auto-closes the open `<p>` on encountering `<pre>`),
    # so the locus line uses a `<div>` wrapper instead.
    def render_locus
      div(class: "mb-3") do
        strong { "#{:LOCUS.l}:" }
        plain(" ")
        pre(class: "d-inline text-monospace") { plain(@sequence.locus) }
      end
    end

    def render_bases
      p do
        strong { "#{:BASES.l}:" }
      end
      pre(class: "text-monospace",
          style: "white-space: pre-wrap; word-break: break-all") do
        plain(@sequence.bases)
      end
    end

    def render_deposit
      p do
        strong { "#{:DEPOSIT.l}:" }
        plain(" ")
        render_archive_link
        plain(": ")
        render_accession_link
      end
    end

    def render_blast_link
      p do
        link_to(:show_observation_blast_link.l, @sequence.blast_url,
                class: "btn btn-default", target: "_blank", rel: "noopener")
      end
    end

    def render_archive_link
      url = ::WebSequenceArchive.archive_home(@sequence.archive)
      link_to(@sequence.archive.t, url, target: "_blank", rel: "noopener")
    end

    def render_accession_link
      link_to(truncate(@sequence.accession,
                       length: @sequence.locus_width / 2).t,
              @sequence.accession_url, target: "_blank", rel: "noopener")
    end
  end
end
