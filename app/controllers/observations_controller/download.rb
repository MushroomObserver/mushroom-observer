# frozen_string_literal: true

# see observations_controller.rb
module ObservationsController::Download
  def download
    @query = find_or_create_query(:Observation, by: params[:by])
    raise("no robots!") if browser.bot?

    query_params_set(@query)
    @format = params[:format] || "raw"
    @encoding = params[:encoding] || "UTF-8"
    download_observations_switch
  rescue StandardError => e
    flash_error("Internal error: #{e}", *e.backtrace[0..10])
  end

  def print_labels
    query = find_query(:Observation)
    if query
      @labels = make_labels(query.results)
      render(action: :print_labels, layout: :printable)
    else
      flash_error(:runtime_search_has_expired.t)
      redirect_back_or_default("/")
    end
  end

  private

  def download_observations_switch
    if params[:commit] == :CANCEL.l
      redirect_with_query(action: :index, always_index: true)
    elsif params[:commit] == :DOWNLOAD.l
      create_and_render_report
    elsif params[:commit] == :download_observations_print_labels.l
      render_labels
    end
  end

  def create_and_render_report
    report = create_report(
      query: @query, format: @format, encoding: @encoding
    )
    render_report(report)
  end

  def render_labels
    @labels = make_labels(@query.results)
    render(action: :print_labels, layout: :printable)
  end

  def create_report(args)
    format = args[:format].to_s
    case format
    when "raw"
      Report::Raw.new(args)
    when "adolf"
      Report::Adolf.new(args)
    when "darwin"
      Report::Dwca.new(args)
    when "symbiota"
      Report::Symbiota.new(args)
    when "fundis"
      Report::Fundis.new(args)
    else
      raise("Invalid download type: #{format.inspect}")
    end
  end

  def render_report(report)
    send_data(report.body, {
      type: report.mime_type,
      charset: report.encoding,
      disposition: "attachment",
      filename: report.filename
    }.merge(report.header || {}))
  end

  def make_labels(observations)
    @fundis_herbarium = Herbarium.where(
      name: "Fungal Diversity Survey"
    ).first
    observations.map do |observation|
      make_label(observation)
    end
  end

  def make_label(observation)
    rows = label_data(observation)
    insert_fundis_id(rows, observation)
    rows
  end

  def label_data(observation)
    [
      ["MO #", observation.id],
      ["When", observation.when],
      ["Who", observation.collector_and_number],
      ["Where", observation.place_name_and_coordinates],
      ["What", observation.format_name.t],
      ["Notes", observation.notes_export_formatted.t]
    ]
  end

  def insert_fundis_id(rows, observation)
    return unless @fundis_herbarium

    fundis_record = observation.herbarium_records.where(
      herbarium: @fundis_herbarium
    ).first
    return unless fundis_record

    rows.insert(1, ["FunDiS #", fundis_record.accession_number])
  end
end
