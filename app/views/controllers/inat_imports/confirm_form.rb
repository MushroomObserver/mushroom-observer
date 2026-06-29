# frozen_string_literal: true

module Views::Controllers::InatImports
  # Confirmation form for iNat import. Shows expected import count
  # and Proceed/Go Back buttons. Hidden fields carry form data
  # through the confirmation step. Rendered by `confirm.rb`.
  class ConfirmForm < ::Components::ApplicationForm
    include ::Inat::Constants

    def initialize(model, expected: nil, unlicensed_obs: nil,
                   breakdown: {}, **)
      @expected = expected
      @unlicensed_obs = unlicensed_obs
      @inat_import = breakdown[:inat_import]
      @requested = breakdown[:requested]
      @after_taxon = breakdown[:after_taxon]
      @estimate_with_date = breakdown[:estimate_with_date]
      @estimated_at = Time.current
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
      render(Components::Panel.new) do |panel|
        panel.with_body do
          render_timestamp_note
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
      render_ignored_total
      render_ignored_overlap_note if rows.size > 1
      div(class: "ml-3") do
        rows.each do |row|
          render_ignored_row(row[:key], row[:count], row[:url])
        end
      end
      br
    end

    def render_ignored_total
      return unless @requested && (@estimate_with_date || @expected)

      total = @requested.to_i - (@estimate_with_date || @expected).to_i
      b { plain(:inat_import_confirm_ignored_total_caption.l) }
      plain(": ")
      span(id: "total_ignored_count") { plain(total.to_s) }
    end

    def render_ignored_overlap_note
      div { small(class: "overlap-note") { plain(overlap_note) } }
    end

    def overlap_note = :inat_import_confirm_ignored_overlap_note.l

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
        count: @unlicensed_obs.to_i, url: unlicensed_obs_url }
    end

    def not_importable_count
      @requested.to_i - @after_taxon.to_i if @requested && @after_taxon
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
          link_to((@estimate_with_date || @expected).to_s, url,
                  target: "_blank", rel: "noopener noreferrer")
        else
          plain((@estimate_with_date || @expected).to_s)
        end
      end
    end

    def render_timestamp_note
      return unless @expected

      t = @estimated_at.strftime("%Y-%m-%d %H:%M:%S %Z")
      p(id: "as_of") { plain(:inat_import_confirm_expected_as_of.t(time: t)) }
      return unless show_staleness_note?

      stale = :inat_import_confirm_expected_staleness.l
      p(class: "staleness-note") { plain(stale) }
    end

    def show_staleness_note? = !stable_result_set?

    def stable_result_set?
      return true if model.inat_ids.present?
      return false unless (query = requested_obs_query)

      qs = query.start_with?("http") ? query.split("?", 2)[1].to_s : query
      args = Rack::Utils.parse_query(qs)
      args["id"].present? || date_filtered_before_estimated_at?(args)
    end

    def date_filtered_before_estimated_at?(args)
      date = d2_date(args) || year_end_date(args)
      date && date < @estimated_at.to_date
    rescue ArgumentError
      false
    end

    def d2_date(args)
      Date.parse(args["d2"]) if args["d2"].present?
    end

    def year_end_date(args)
      return unless (year = args["year"]&.to_i)

      Date.new(year, args["month"]&.to_i || 12, args["day"]&.to_i || -1)
    end

    def expected_obs_url
      base = requested_obs_url
      return nil unless base

      uri, query_str = base.split("?", 2)
      "#{uri}?#{expected_obs_args(query_str).to_query}"
    end

    def expected_obs_args(query_str)
      args = Rack::Utils.parse_query(query_str.to_s)
      args["iconic_taxa"] ||= "Fungi,Protozoa" unless args.key?("taxon_id")
      args["without_field"] = BASE_FILTER_PARAMS[:without_field]
      args["d1"] ||= EARLIEST_DATE_FILTER
      filter = LICENSED_FILTER.stringify_keys.transform_values(&:to_s)
      args.merge!(filter) if import_others?
      args
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
      format_hms((@estimate_with_date || @expected) * avg_import_seconds)
    end

    def avg_import_seconds
      @inat_import&.initial_avg_import_seconds ||
        InatImport::BASE_AVG_IMPORT_SECONDS
    end

    def format_hms(seconds)
      s = seconds.to_i
      Kernel.format("%02d:%02d:%02d", s / 3600, s % 3600 / 60, s % 60)
    end

    def render_ignored_row(caption_key, count, url)
      link_opts = { target: "_blank", rel: "noopener noreferrer" }
      div(class: "mb-1") do
        b { plain("#{caption_key.l}: ") }
        url ? link_to(count.to_s, url, **link_opts) : plain(count.to_s)
      end
    end

    def already_imported_count
      return unless @after_taxon && @expected

      diff = @after_taxon.to_i - @expected.to_i
      import_others? ? diff - @unlicensed_obs.to_i : diff
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

      # https://forum.inaturalist.org/t/how-to-use-inaturalists-search-urls-wiki-part-2-of-2/18792#heading--obs--field
      "#{base}&field:Mushroom%20Observer%20URL"
    end

    def unlicensed_obs_url
      requested_obs_url&.then { |u| "#{u}&licensed=false" }
    end

    def inat_obs_search_url(query_string)
      "#{SITE}/observations?#{query_string}"
    end

    def render_explanation = p { plain(:inat_import_confirm_explanation.l) }

    def render_prompt = p { plain(:inat_import_confirm_prompt.l) }

    def render_hidden_fields
      [:inat_username, :inat_ids, :import_all, :consent, :import_others,
       :inat_url, :original_inat_url, :skip_inat_writeback].each do |f|
        hidden_field(f)
      end
    end

    def render_buttons
      div(class: "mt-3") do
        submit(:inat_import_confirm_proceed.l, as: :button,
                                               name: "confirmed", value: "1")
        whitespace
        submit(:inat_import_confirm_go_back.l, as: :button,
                                               name: "go_back", value: "1")
      end
    end

    def import_others? = model.import_others == "1"
  end
end
