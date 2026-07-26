# frozen_string_literal: true

module Views::Controllers::InatImports
  # Confirmation form for iNat import. Shows expected import count
  # and Proceed/Go Back buttons. Hidden fields carry form data
  # through the confirmation step. Rendered by `confirm.rb`.
  class ConfirmForm < ::Components::ApplicationForm
    def initialize(model, expected: nil, unlicensed_obs: nil,
                   breakdown: {}, **)
      @expected = expected
      @unlicensed_obs = unlicensed_obs
      @inat_import = breakdown[:inat_import]
      @requested = breakdown[:requested]
      @after_taxon = breakdown[:after_taxon]
      @not_yet_imported = breakdown[:not_yet_imported]
      @estimate_with_date = breakdown[:estimate_with_date]
      @estimated_at = Time.current
      @urls = ::Inat::ConfirmURLBuilder.new(model)
      super(model, **)
    end

    def view_template
      render_expected
      render_explanation
      render_prompt
      render_hidden_fields
      render_buttons
    end

    def form_action = inat_imports_path

    private

    def render_expected
      Panel do |panel|
        panel.with_body do
          render_timestamp_note
          if @requested
            requested_obs_line
            br
          end
          render_ignored_section
          count_expected_line
          render_nothing_to_import_notice
          br
          render_unlicensed_line
          br
          time_estimate_line
        end
      end
    end

    def render_timestamp_note
      return unless @expected

      t = @estimated_at.strftime("%Y-%m-%d %H:%M:%S %Z")
      p(id: "as_of") { plain(:inat_import_confirm_expected_as_of.t(time: t)) }
      return if stable_result_set?

      p(class: "staleness-note") do
        plain(:inat_import_confirm_expected_staleness.l)
      end
    end

    def stable_result_set? = @urls.stable_result_set?

    def requested_obs_line
      b { plain(:inat_import_confirm_requested_caption.l) }
      plain(": ")
      span(id: "requested_count") do
        url = requested_obs_url
        if url
          render(Components::Link::External.new(content: @requested.to_s,
                                                path: url))
        else
          plain(@requested.to_s)
        end
      end
    end

    def requested_obs_url = @urls.requested_obs_url

    def render_ignored_section
      return unless show_ignored_section?

      br
      render_ignored_total
      render_ignored_overlap_note if ignored_rows_count > 1
      div(class: "ml-3") do
        ignored_row_data.each do |row|
          render_ignored_row(row[:key], row[:count], row[:url])
        end
        unlicensed_ignored_row if skip_unlicensed_others?
      end
      br
    end

    def show_ignored_section?
      ignored_row_data.any? ||
        # Import-others' unlicensed obs, when create_skeletons is off, are
        # never imported. So they belong here rather than in a skeleton/
        # own-import informational-only line (#4828).
        skip_unlicensed_others?
    end

    def create_skeletons? = model.create_skeletons == "1"

    # True only when import-others' unlicensed obs will genuinely be
    # skipped — i.e. the superimporter unchecked create_skeletons (#4828).
    # When it's checked (the default), those obs are imported as skeleton
    # counterparts, so they don't belong in the ignored breakdown.
    def skip_unlicensed_others? = import_others? && !create_skeletons?

    def ignored_row_data
      [not_importable_row, already_imported_row, no_date_row].compact
    end

    def not_importable_row
      return unless (c = not_importable_count)&.positive?

      { key: :inat_import_confirm_not_importable_caption, count: c, url: nil }
    end

    def not_importable_count
      @requested.to_i - @after_taxon.to_i if @requested && @after_taxon
    end

    def already_imported_row
      return unless (c = already_imported_count)&.positive?

      { key: :inat_import_confirm_already_imported_caption,
        count: c, url: already_imported_url }
    end

    def already_imported_count
      return unless @after_taxon && @not_yet_imported

      @after_taxon.to_i - @not_yet_imported.to_i
    end

    def already_imported_url = @urls.already_imported_url

    def no_date_row
      return unless (c = no_date_count)&.positive?

      { key: :inat_import_confirm_no_date_caption, count: c, url: nil }
    end

    def no_date_count
      return unless @expected && @estimate_with_date

      @expected.to_i - @estimate_with_date.to_i
    end

    def import_others? = model.import_others == "1"

    def render_ignored_total
      return unless @requested && (@estimate_with_date || @expected)

      total = @requested.to_i - (@estimate_with_date || @expected).to_i
      b { plain(:inat_import_confirm_ignored_total_caption.l) }
      plain(": ")
      span(id: "total_ignored_count") { plain(total.to_s) }
    end

    def render_ignored_overlap_note
      div do
        small(class: "overlap-note") do
          plain(:inat_import_confirm_ignored_overlap_note.l)
        end
      end
    end

    def ignored_rows_count
      ignored_row_data.size + (skip_unlicensed_others? ? 1 : 0)
    end

    def render_ignored_row(caption_key, count, url)
      div(class: "mb-1") do
        b { plain("#{caption_key.l}: ") }
        if url
          render(Components::Link::External.new(content: count.to_s,
                                                path: url))
        else
          plain(count.to_s)
        end
      end
    end

    # Only rendered when create_skeletons is off (skip_unlicensed_others?) —
    # in that case import-others' unlicensed obs are never imported, so this
    # lives inside the Total Ignored Observations breakdown rather than as
    # its own always-visible line. Rendered unconditionally within that case
    # (even when the count is blank/zero) so a failed estimate is visible as
    # blank, distinguishable from a genuine zero.
    def unlicensed_ignored_row
      div(class: "mb-1") do
        b { plain("#{:inat_import_confirm_unlicensed_obs_caption.l}: ") }
        span(id: "unlicensed_obs_count") { render_unlicensed_count }
        if @unlicensed_obs.to_i.positive?
          whitespace
          plain(unlicensed_note_key.l)
        end
      end
    end

    def render_unlicensed_count
      url = unlicensed_obs_url
      if url
        render(Components::Link::External.new(content: @unlicensed_obs.to_s,
                                              path: url))
      else
        plain(@unlicensed_obs.to_s)
      end
    end

    def unlicensed_obs_url = @urls.unlicensed_obs_url

    def unlicensed_note_key
      if import_others?
        :inat_import_confirm_unlicensed_others_note
      else
        :inat_import_confirm_unlicensed_obs_note
      end
    end

    def count_expected_line
      b { plain(:inat_import_confirm_expected_caption.l) }
      plain(": ")
      span(id: "expected_count") do
        url = expected_obs_url
        count = (@estimate_with_date || @expected).to_s
        if url
          render(Components::Link::External.new(content: count, path: url))
        else
          plain(count)
        end
      end
    end

    def expected_obs_url = @urls.expected_obs_url

    def render_nothing_to_import_notice
      # Match the count that drives the display and the Proceed button, so
      # the notice shows whenever that count is 0 (e.g. all obs undated).
      return unless (@estimate_with_date || @expected)&.zero?

      p { plain(:inat_import_confirm_nothing_to_import.l) }
    end

    # Own-imports: an informational line about unlicensed obs (default MO
    # license applied to their images). Import-others with create_skeletons
    # off: nothing here — that count lives in the ignored-total breakdown
    # instead (see unlicensed_ignored_row). Import-others with
    # create_skeletons on (the default, #4828): a skeleton-specific line,
    # since those obs are genuinely imported, just as lighter records.
    def render_unlicensed_line
      if import_others?
        skeleton_obs_line if create_skeletons?
      else
        unlicensed_obs_line
      end
    end

    def unlicensed_obs_line
      b { plain(:inat_import_confirm_unlicensed_obs_caption.l) }
      plain(": ")
      span(id: "unlicensed_obs_count") { render_unlicensed_count }
      return unless @unlicensed_obs.to_i.positive?

      whitespace
      plain(unlicensed_note_key.l)
    end

    def skeleton_obs_line
      b { plain(:inat_import_confirm_skeleton_obs_caption.l) }
      plain(": ")
      span(id: "unlicensed_obs_count") { render_unlicensed_count }
    end

    def time_estimate_line
      b { plain(:inat_import_confirm_time_estimate_caption.l) }
      plain(": ")
      span(id: "estimated_time") { plain(estimated_time) }
    end

    def estimated_time
      format_hms((@estimate_with_date || @expected) * avg_import_seconds)
    end

    def format_hms(seconds)
      s = seconds.to_i
      Kernel.format("%02d:%02d:%02d", s / 3600, s % 3600 / 60, s % 60)
    end

    def avg_import_seconds
      @inat_import&.initial_avg_import_seconds ||
        InatImport::BASE_AVG_IMPORT_SECONDS
    end

    def render_explanation = p { plain(:inat_import_confirm_explanation.l) }

    def render_prompt = p { plain(:inat_import_confirm_prompt.l) }

    def render_hidden_fields
      [:inat_username, :inat_ids, :import_all, :consent, :import_others,
       :create_skeletons, :inat_url, :original_inat_url, :recheck_all,
       :skip_inat_writeback].each do |f|
        hidden_field(f)
      end
    end

    def render_buttons
      div(class: "mt-3") do
        submit(:inat_import_confirm_proceed.l, as: :button,
                                               name: "confirmed", value: "1",
                                               disabled: nothing_to_import?)
        whitespace
        submit(:inat_import_confirm_go_back.l, as: :button,
                                               name: "go_back", value: "1")
      end
    end

    def nothing_to_import? = (@estimate_with_date || @expected).to_i.zero?
  end
end
