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
    process_species_list(:create)
  end

  # Specialized javascripty form for creating a list of names, at Darvin's
  # request. Links into "new".
  def name_lister # :norobots:
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

    if !check_permission!(@species_list) redirect_to @species_list
    init_name_vars_for_edit(@species_list)
    init_member_vars_for_edit(@species_list)
    init_project_vars_for_edit(@species_list)
    @checklist ||= calc_checklist
  end

  alias_method :edit_species_list, :edit

  def update
    process_species_list(:update)
  end

  # Form to let user create/edit species_list from file. Links into "edit".
  def upload_species_list # :norobots:
    @species_list = find_or_goto_index(SpeciesList, params[:id].to_s)
    return unless @species_list

    if !check_permission!(@species_list)
      redirect_to @species_list
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

  def destroy # :norobots:
    @species_list = find_or_goto_index(SpeciesList, params[:id].to_s)
    return unless @species_list

    if check_permission!(@species_list)
      @species_list.destroy
      id = params[:id].to_s
      flash_notice(:runtime_species_list_destroy_success.t(id: id))
      redirect_to action: :index
    else
      redirect_to @species_list
    end
  end

  alias_method :destroy_species_list, :destroy

end
