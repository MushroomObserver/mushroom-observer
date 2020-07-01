# frozen_string_literal: true

# see app/controllers/species_lists_controller.rb
class SpeciesListsController

  ##############################################################################
  #
  #  :section: Create and Modify
  #
  ##############################################################################

  def new # :prefetch: :norobots:
    @species_list = SpeciesList.new
    init_name_vars_for_create
    init_member_vars_for_create
    init_project_vars_for_create
    init_name_vars_for_clone(params[:clone]) if params[:clone].present?
    @checklist ||= calc_checklist
  end

  alias_method :create_species_list, :new

  def create
    @species_list = SpeciesList.new
    return if process_species_list(:create)

    render "new"
  end

  # Specialized javascripty form for creating a list of names, at Darvin's
  # request. Links into "new".
  def name_lister
    # Names are passed in as string, one name per line.
    results = params[:results] || ""
    @name_strings = results.chomp.split("\n").map { |n| n.to_s.chomp }
    return if request.method != "POST"

    # (make this an instance var to give unit test access)
    @names = @name_strings.map do |str|
      str.sub!(/\*$/, "")
      name, author = str.split("|")
      name.tr!("ë", "e")
      if author
        Name.find_by_text_name_and_author(name, author)
      else
        Name.find_by_text_name(name)
      end
    end
    @names.reject!(&:nil?)
    case params[:commit]
    when :name_lister_submit_spl.l
      if @user
        @species_list = SpeciesList.new
        clear_query_in_session
        init_name_vars_for_create
        init_member_vars_for_create
        init_project_vars_for_create
        @checklist ||= []
        @list_members = params[:results].tr("|", " ").delete("*")
        render(action: :new)
      end
    when :name_lister_submit_txt.l
      render_name_list_as_txt(@names)
    when :name_lister_submit_rtf.l
      render_name_list_as_rtf(@names)
    when :name_lister_submit_csv.l
      render_name_list_as_csv(@names)
    else
      flash_error(:name_lister_bad_submit.t(button: params[:commit]))
    end
  end

  def edit # :prefetch: :norobots:
    @species_list = find_or_goto_index(SpeciesList, params[:id].to_s)
    return unless @species_list

    unless check_permission!(@species_list)
      redirect_to species_list_path(@species_list.id)
    else
      init_name_vars_for_edit(@species_list)
      init_member_vars_for_edit(@species_list)
      init_project_vars_for_edit(@species_list)
      @checklist ||= calc_checklist
    end
  end

  alias_method :edit_species_list, :edit

  def update
    @species_list = find_or_goto_index(SpeciesList, params[:id].to_s)
    return unless @species_list

    unless check_permission!(@species_list)
      redirect_to species_list_path(@species_list.id)
    else
      return if process_species_list(:update)
      render :edit
    end
  end

  # Used by show_species_list.
  def make_report
    @species_list = find_or_goto_index(SpeciesList, params[:id].to_s)
    return unless @species_list

    names = @species_list.names
    case params[:type]
    when "txt"
      render_name_list_as_txt(names)
    when "rtf"
      render_name_list_as_rtf(names)
    when "csv"
      render_name_list_as_csv(names)
    else
      flash_error(:make_report_not_supported.t(type: params[:type]))
      redirect_to(action: "show_species_list", id: params[:id].to_s)
    end
  end

  # Form to let user create/edit species_list from file. Links into "edit".
  def upload_species_list
    @species_list = find_or_goto_index(SpeciesList, params[:id].to_s)
    return unless @species_list

    if !check_permission!(@species_list)
      redirect_to species_list_path(@species_list.id)
    elsif request.method != "POST"
      query = create_query(
        :Observation,
        :in_species_list,
        by: :name,
        species_list: @species_list
      )
      @observation_list = query.results
    else
      sorter = NameSorter.new
      @species_list.file = params[:species_list][:file]
      @species_list.process_file_data(sorter)
      init_name_vars_from_sorter(@species_list, sorter)
      init_member_vars_for_edit(@species_list)
      init_project_vars_for_edit(@species_list)
      @checklist ||= calc_checklist
      render action: :edit
    end
  end

  def destroy
    @species_list = find_or_goto_index(SpeciesList, params[:id].to_s)
    return unless @species_list

    if check_permission!(@species_list)
      @species_list.destroy
      id = params[:id].to_s
      flash_notice(:runtime_species_list_destroy_success.t(id: id))
      redirect_to action: :index
    else
      redirect_to species_list_path(@species_list.id)
    end
  end

  alias_method :destroy_species_list, :destroy

  ##############################################################################

  private

  def render_name_list_as_txt(names)
    charset = "UTF-8"
    str = "\xEF\xBB\xBF" + names.map(&:real_search_name).join("\r\n")
    send_data(str, type: "text/plain",
                   charset: charset,
                   disposition: "attachment",
                   filename: "report.txt")
  end

  def render_name_list_as_csv(names)
    charset = "ISO-8859-1"
    str = CSV.generate do |csv|
      csv << %w[scientific_name authority citation accepted]
      names.each do |name|
        csv << [name.real_text_name, name.author, name.citation,
                name.deprecated ? "" : "1"].map(&:presence)
      end
    end
    str = str.iconv(charset)
    send_data(str, type: "text/csv",
                   charset: charset,
                   header: "present",
                   disposition: "attachment",
                   filename: "report.csv")
  end

  def render_name_list_as_rtf(names)
    charset = "UTF-8"
    doc = RTF::Document.new(RTF::Font::SWISS)
    names.each do |name|
      rank      = name.rank
      text_name = name.real_text_name
      author    = name.author
      node = name.deprecated ? doc : doc.bold
      if [:Genus, :Species, :Subspecies, :Variety, :Form].include?(rank)
        node = node.italic
      end
      node << text_name
      doc << " " + author if author.present?
      doc.line_break
    end
    send_data(doc.to_rtf, type: "text/rtf",
                          charset: charset,
                          disposition: "attachment",
                          filename: "report.rtf")
  end
end
