# frozen_string_literal: true

module Views::Controllers::InatImports
  # Confirmation form for iNat import. Shows expected import count
  # and Proceed/Go Back buttons. Hidden fields carry form data
  # through the confirmation step. Rendered by `confirm.rb`.
  class ConfirmForm < ::Components::ApplicationForm
    # breakdown: hash with :inat_import, :requested, :after_taxon,
    # :estimate_with_date — iNat API counts from the confirm step.
    def initialize(model, expected: nil, unlicensed_obs: nil,
                   breakdown: {}, **)
      @expected = expected
      @unlicensed_obs = unlicensed_obs
      @inat_import = breakdown[:inat_import]
      @requested = breakdown[:requested]
      @after_taxon = breakdown[:after_taxon]
      @estimate_with_date = breakdown[:estimate_with_date]
      super(model, **)
    end

    def view_template
      render_expected
      render_ignored_section if show_ignored_section?
      render_explanation
      render_prompt
      render_hidden_fields
      render_buttons
    end

    def form_action
      inat_imports_path
    end

    private

    def render_expected
      render(Components::Panel.new) do |panel|
        panel.with_body do
          if @requested
            requested_obs_line
            br
          end
          count_expected_line
          unless import_others?
            br
            unlicensed_obs_line
          end
          br
          time_estimate_line
        end
      end
    end

    def requested_obs_line
      b { plain(:inat_import_confirm_requested_caption.l) }
      plain(": ")
      span(id: "requested_count") do
        url = requested_obs_url
        if url
          link_to(@requested.to_s, url,
                  target: "_blank", rel: "noopener noreferrer")
        else
          plain(@requested.to_s)
        end
      end
    end

    def count_expected_line
      b { plain(:inat_import_confirm_expected_caption.l) }
      plain(": ")
      span(id: "expected_count") { plain(expected_count) }
    end

    def expected_count
      @expected.to_s
    end

    def unlicensed_obs_line
      b { plain(:inat_import_confirm_unlicensed_obs_caption.l) }
      plain(": ")
      span(id: "unlicensed_obs_count") { plain(@unlicensed_obs.to_s) }
      return unless @unlicensed_obs.to_i.positive?

      plain(" ")
      plain(:inat_import_confirm_unlicensed_obs_note.l)
    end

    def time_estimate_line
      b { plain(:inat_import_confirm_time_estimate_caption.l) }
      plain(": ")
      span(id: "estimated_time") { plain(estimated_time) }
    end

    def estimated_time
      seconds = @expected * avg_import_seconds
      format_hms(seconds)
    end

    def avg_import_seconds
      @inat_import&.initial_avg_import_seconds ||
        InatImport::BASE_AVG_IMPORT_SECONDS
    end

    def format_hms(seconds)
      total_seconds = seconds.to_i
      hours = total_seconds / 3600
      minutes = (total_seconds % 3600) / 60
      remaining = total_seconds % 60
      Kernel.format("%02d:%02d:%02d", hours, minutes, remaining)
    end

    def show_ignored_section?
      @requested && @estimate_with_date &&
        @requested.to_i > @estimate_with_date.to_i
    end

    def render_ignored_section
      render(Components::Panel.new) do |panel|
        panel.with_body do
          h5 { plain(:inat_import_confirm_ignored_heading.l) }
          render_ignored_not_importable_row
          render_ignored_already_imported_row
          render_ignored_no_date_row
          render_ignored_unlicensed_row if import_others?
        end
      end
    end

    def render_ignored_not_importable_row
      return unless @requested && @after_taxon

      count = @requested.to_i - @after_taxon.to_i
      return unless count.positive?

      render_ignored_row(:inat_import_confirm_not_importable_caption,
                         count, nil)
    end

    def render_ignored_already_imported_row
      count = already_imported_count
      return unless count&.positive?

      render_ignored_row(:inat_import_confirm_already_imported_caption,
                         count, already_imported_url)
    end

    def render_ignored_no_date_row
      return unless @expected && @estimate_with_date

      count = @expected.to_i - @estimate_with_date.to_i
      return unless count.positive?

      render_ignored_row(:inat_import_confirm_no_date_caption, count, nil)
    end

    def render_ignored_unlicensed_row
      count = @unlicensed_obs.to_i
      return unless count.positive?

      div(class: "mb-1") do
        b { plain("#{:inat_import_confirm_unlicensed_obs_caption.l}: ") }
        span(id: "ignored_unlicensed_count") { plain(count.to_s) }
      end
    end

    def render_ignored_row(caption_key, count, url)
      div(class: "mb-1") do
        b { plain("#{caption_key.l}: ") }
        if url
          link_to(count.to_s, url,
                  target: "_blank", rel: "noopener noreferrer")
        else
          plain(count.to_s)
        end
      end
    end

    def already_imported_count
      return unless @after_taxon && @expected

      if import_others?
        @after_taxon.to_i - @expected.to_i - @unlicensed_obs.to_i
      else
        @after_taxon.to_i - @expected.to_i
      end
    end

    def requested_obs_url
      query = requested_obs_query
      return nil unless query
      return query if query.start_with?("http")

      inat_obs_search_url(query)
    end

    # Returns a full URL (for original_inat_url) or a query string
    # fragment that inat_obs_search_url will prepend the base to.
    def requested_obs_query
      m = model
      return "id=#{m.inat_ids}" if m.inat_ids.present?
      return m.original_inat_url if m.original_inat_url.present?
      return m.inat_url if m.inat_url.present?

      "user_id=#{m.inat_username}" if m.inat_username.present?
    end

    def already_imported_url
      base = requested_obs_url
      return nil unless base

      "#{base}&with_field=Mushroom+Observer+URL"
    end

    def inat_obs_search_url(query_string)
      "#{::Inat::Constants::SITE}/observations?#{query_string}"
    end

    def render_explanation
      p { plain(:inat_import_confirm_explanation.l) }
    end

    def render_prompt
      p { plain(:inat_import_confirm_prompt.l) }
    end

    def render_hidden_fields
      hidden_field(:inat_username)
      hidden_field(:inat_ids)
      hidden_field(:import_all)
      hidden_field(:consent)
      hidden_field(:import_others)
      hidden_field(:inat_url)
      hidden_field(:original_inat_url)
      hidden_field(:skip_inat_writeback)
    end

    def render_buttons
      div(class: "mt-3") do
        proceed_button
        whitespace
        go_back_button
      end
    end

    def proceed_button
      submit(:inat_import_confirm_proceed.l, as: :button,
                                             name: "confirmed", value: "1")
    end

    def go_back_button
      submit(:inat_import_confirm_go_back.l, as: :button,
                                             name: "go_back", value: "1")
    end

    def import_others?
      model.import_others == "1"
    end
  end
end
