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
          render_ignored_section
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

    def render_ignored_section
      rows = ignored_row_data
      return if rows.empty?

      br
      render_ignored_total(rows)
      render_ignored_overlap_note if rows.size > 1
      div(class: "ml-3") do
        rows.each do |row|
          render_ignored_row(row[:key], row[:count], row[:url])
        end
      end
      br
    end

    def render_ignored_total(rows)
      b { plain(:inat_import_confirm_ignored_total_caption.l) }
      plain(": ")
      span(id: "total_ignored_count") do
        plain(rows.sum { |r| r[:count] }.to_s)
      end
    end

    def render_ignored_overlap_note
      div { small { plain(:inat_import_confirm_ignored_overlap_note.l) } }
    end

    def ignored_row_data
      [not_importable_row, already_imported_row,
       no_date_row, unlicensed_row].compact
    end

    def not_importable_row
      return unless (c = not_importable_count)&.positive?

      { key: :inat_import_confirm_not_importable_caption, count: c, url: nil }
    end

    def already_imported_row
      return unless (c = already_imported_count)&.positive?

      { key: :inat_import_confirm_already_imported_caption,
        count: c, url: already_imported_url }
    end

    def no_date_row
      return unless (c = no_date_count)&.positive?

      { key: :inat_import_confirm_no_date_caption, count: c, url: nil }
    end

    def unlicensed_row
      return unless import_others? && @unlicensed_obs.to_i.positive?

      { key: :inat_import_confirm_unlicensed_obs_caption,
        count: @unlicensed_obs.to_i, url: nil }
    end

    def not_importable_count
      return unless @requested && @after_taxon

      @requested.to_i - @after_taxon.to_i
    end

    def no_date_count
      return unless @expected && @estimate_with_date

      @expected.to_i - @estimate_with_date.to_i
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
      span(id: "expected_count") do
        url = expected_obs_url
        if url
          link_to(expected_count, url,
                  target: "_blank", rel: "noopener noreferrer")
        else
          plain(expected_count)
        end
      end
    end

    def expected_obs_url
      base = requested_obs_url
      return nil unless base

      uri, query_str = base.split("?", 2)
      args = Rack::Utils.parse_query(query_str.to_s)
      unless args.key?("taxon_id") || args.key?("iconic_taxa")
        args["iconic_taxa"] = "Fungi,Protozoa"
      end
      args["without_field"] =
        ::Inat::Constants::BASE_FILTER_PARAMS[:without_field]
      if import_others?
        args["license"] = ::Inat::Constants::LICENSED_FILTER[:license]
      end
      "#{uri}?#{args.to_query}"
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
      return normalize_inat_ui_url(query) if query.start_with?("http")

      inat_obs_search_url(translate_api_to_ui_params(query))
    end

    # iNat UI does not support comma-separated taxon_id values; replace
    # with iconic_taxa when more than one taxon ID is present.
    def translate_api_to_ui_params(query_str)
      args = Rack::Utils.parse_query(query_str.to_s)
      return args.to_query unless args["taxon_id"]&.include?(",")

      args.except("taxon_id").merge("iconic_taxa" => "Fungi,Protozoa").to_query
    end

    def normalize_inat_ui_url(url)
      uri, query_str = url.split("?", 2)
      "#{uri}?#{translate_api_to_ui_params(query_str.to_s)}"
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
