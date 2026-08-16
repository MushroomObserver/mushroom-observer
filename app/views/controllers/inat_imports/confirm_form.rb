# frozen_string_literal: true

module Views::Controllers::InatImports
  # Confirmation form for iNat import. Shows expected import count
  # and Proceed/Go Back buttons. Hidden fields carry form data
  # through the confirmation step. Rendered by `confirm.rb`.
  class ConfirmForm < ::Components::ApplicationForm
    prop :expected, _Nilable(::Integer), default: nil
    prop :unlicensed_obs, _Nilable(::Integer), default: nil
    prop :inat_import, _Nilable(::InatImport), default: nil
    prop :requested, _Nilable(::Integer), default: nil
    prop :after_taxon, _Nilable(::Integer), default: nil
    prop :not_yet_imported, _Nilable(::Integer), default: nil
    prop :estimate_with_date, _Nilable(::Integer), default: nil
    prop :estimated_at, ::Time, default: -> { Time.current }
    prop :urls, ::Inat::ConfirmURLBuilder

    def initialize(model, expected: nil, unlicensed_obs: nil,
                   breakdown: {}, **)
      super(model,
            expected: expected,
            unlicensed_obs: unlicensed_obs,
            inat_import: breakdown[:inat_import],
            requested: breakdown[:requested],
            after_taxon: breakdown[:after_taxon],
            not_yet_imported: breakdown[:not_yet_imported],
            estimate_with_date: breakdown[:estimate_with_date],
            urls: ::Inat::ConfirmURLBuilder.new(model),
            **)
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

    include IgnoredSection

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

    def import_others? = model.import_others == "1"

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
        # data-turbo="false": this submit redirects to iNaturalist's
        # OAuth authorize page (an external host). Turbo Drive's
        # fetch-based form submission follows redirects as fetch
        # requests, not real navigations -- a cross-origin redirect
        # there doesn't land the browser on iNat's login page the way
        # a plain form submit does. Opting this one button out of
        # Turbo keeps the redirect a normal top-level navigation.
        submit(:inat_import_confirm_proceed.l, as: :button,
                                               name: "confirmed", value: "1",
                                               disabled: nothing_to_import?,
                                               data: { turbo: "false" })
        whitespace
        submit(:inat_import_confirm_go_back.l, as: :button,
                                               name: "go_back", value: "1")
      end
    end

    def nothing_to_import? = (@estimate_with_date || @expected).to_i.zero?
  end
end
