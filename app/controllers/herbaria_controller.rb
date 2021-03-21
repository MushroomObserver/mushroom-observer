# frozen_string_literal: true

# View and modify Herbaria (displayed as "Fungaria")
#
# Actions
# -------
# create (post)
# destroy (delete)
# edit (get)
# index (get)                      (default) list query results
# index (get, pattern: present)    list Herbaria matching a string pattern
# index (get, flavor: nonpersonal) list institutional Herbaria registered in IH
# index (get, flavor: all)         list all Herbaria
# new (get)
# show (get)
# update (patch)
# Herbaria::Curators#create (post)
# Herbaria::Curators#destroy (delete)
# Herbaria::Merges#new (get)
# herbaria::Nexts#show { next: "next" } (get)
# herbaria::Nexts#show { next: "prev" } (get)
# Herbaria::CuratorRequest#new (get)
# Herbaria::CuratorRequest#create (post)

# legacy herbarium Action (method)  upddated herbaria Action (method)
# --------------------------------  ---------------------------------
# create_herbarium (get)            new (get)
# create_herbarium (post)           create (post)
# delete_curator (delete)           Herbaria::Curators#destroy (delete)
# destroy_herbarium (delete)        destroy (delete)
# edit_herbarium (get)              edit (get)
# edit_herbarium (post)             update (patch)
# herbarium_search (get)            index (get, pattern: present)
# index (get)                       index (get, flavor: nonpersonal)
# index_herbarium (get)             index (get) - lists query results
# list_herbaria (get)               index (get, flavor: all) - all herbaria
# merge_herbaria (get)              Herbaria::Merges#new (get)
# next_herbarium (get)              herbaria::Nexts#show { next: "next" } (get)
# prev_herbarium (get)              herbaria::Nexts#show { next: "prev" } (get)
# request_to_be_curator (get)       Herbaria::CuratorRequest#new (get)
# request_to_be_curator (post)      Herbaria::CuratorRequest#create (post)
# show_herbarium (get)              show (get)
# show_herbarium (post)             Herbaria::Curators#create (post)
#
class HerbariaController < ApplicationController
  # filters
  before_action :login_required, only: [:create, :destroy, :edit, :new, :update]
  before_action :store_location, only: [:create, :edit, :new, :show, :update]
  before_action :pass_query_params, only: [
    :create, :destroy, :edit, :new, :show, :update
  ]
  before_action :keep_track_of_referrer, only: [:destroy, :edit, :new]

  # ---------- Actions to Display data (index, show, etc.) ---------------------

  # Display list of selected herbaria, based on params
  #   params[:pattern].present? - Herbaria based on Pattern Search
  #   [:flavor] == "all" - all Herbaria, regardless of query
  #   [:flavor] == "nonpersonal" - all nonpersonal (institutional) Herbaria
  #   default - Herbaria based on current Query (Sort links land on this action)
  def index
    return patterned_index if params[:pattern].present?

    case params[:flavor]
    when "all" # List all herbaria
      show_selected_herbaria(
        create_query(:Herbarium, :all, by: :name), always_index: true
      )
    when "nonpersonal" # List institutional Herbaria
      store_location
      show_selected_herbaria(
        create_query(:Herbarium, :nonpersonal, by: :code_then_name),
        always_index: true
      )
    else # default List herbaria resulting from query
      show_selected_herbaria(
        find_or_create_query(:Herbarium, by: params[:by]),
        id: params[:id].to_s, always_index: true
      )
    end
  end

  def show
    @canonical_url = herbarium_url(params[:id])
    @herbarium = find_or_goto_index(Herbarium, params[:id])
  end

  # ---------- Actions to Display forms -- (new, edit, etc.) -------------------

  def new
    @herbarium = Herbarium.new
  end

  def edit
    @herbarium = find_or_goto_index(Herbarium, params[:id])
    return unless @herbarium
    return unless make_sure_can_edit!

    @herbarium.place_name         = @herbarium.location.try(&:name)
    @herbarium.personal           = @herbarium.personal_user_id.present?
    @herbarium.personal_user_name = @herbarium.personal_user.try(&:login)
  end

  # ---------- Actions to Modify data: (create, update, destroy, etc.) ---------

  def create
    @herbarium = Herbarium.new(herbarium_params)
    normalize_parameters
    return render(:new) unless validate_herbarium!

    @herbarium.save
    @herbarium.add_curator(@user) if @herbarium.personal_user
    notify_admins_of_new_herbarium unless @herbarium.personal_user
    redirect_to_create_location_or_referrer_or_show_location
  end

  def update
    return unless (@herbarium = find_or_goto_index(Herbarium, params[:id]))
    return unless make_sure_can_edit!

    @herbarium.attributes = herbarium_params
    normalize_parameters
    return unless validate_herbarium!

    @herbarium.save
    redirect_to_create_location_or_referrer_or_show_location
  end

  def destroy
    return unless (@herbarium = find_or_goto_index(Herbarium, params[:id]))

    if user_can_destroy_herbarium?
      @herbarium.destroy
      redirect_to_referrer ||
        redirect_with_query(herbaria_path(id: @herbarium.try(&:id)))
    else
      flash_error(:permission_denied.t)
      redirect_to_referrer || redirect_with_query(herbarium_path(@herbarium))
    end
  end

  # ========== Non=standard REST Actions =======================================

  ##############################################################################

  private

  include Herbaria::SharedPrivateMethods

  # ---------- Index -----------------------------------------------------------

  def patterned_index
    pattern = params[:pattern].to_s
    if pattern.match?(/^\d+$/) && (herbarium = Herbarium.safe_find(pattern))
      redirect_to(herbarium_path(herbarium.id))
    else
      show_selected_herbaria(
        create_query(:Herbarium, :pattern_search, pattern: pattern)
      )
    end
  end

  def show_selected_herbaria(query, args = {})
    args = show_index_args(args)

    # Clean up display by removing user-related stuff from nonpersonal index.
    if query.flavor == :nonpersonal
      args[:sorting_links].reject! { |x| x[0] == "user" }
      @no_user_column = true
    end

    # If user clicks "merge" on an herbarium, it reloads the page and asks
    # them to click on the destination herbarium to merge it with.
    @merge = Herbarium.safe_find(params[:merge])
    @links = right_tab_links(query, @links)
    show_index_of_objects(query, args)
  end

  def show_index_args(args)
    { # default args
      letters: "herbaria.name",
      num_per_page: 100,
      include: [:curators, :herbarium_records, :personal_user]
    }.merge(args,
            template: "/herbaria/index.html.erb", # render with this template
            sorting_links: [ # Add some alternate sorting criteria.
              ["records",     :sort_by_records.t],
              ["user",        :sort_by_user.t],
              ["code",        :sort_by_code.t],
              ["name",        :sort_by_name.t],
              ["created_at",  :sort_by_created_at.t],
              ["updated_at",  :sort_by_updated_at.t]
            ])
  end

  def right_tab_links(query, links)
    links ||= []
    unless query.flavor == :all
      links << [:herbarium_index_list_all_herbaria.l,
                herbaria_path(flavor: :all)]
    end
    unless query.flavor == :nonpersonal
      links << [:herbarium_index_nonpersonal_herbaria.l,
                herbaria_path(flavor: :nonpersonal)]
    end
    links << [:create_herbarium.l, new_herbarium_path]
  end

  def make_sure_can_edit!
    return true if in_admin_mode? || @herbarium.can_edit?

    flash_error(:permission_denied.t)
    redirect_to_referrer || redirect_with_query(herbarium_path(@herbarium))
    false
  end

  def normalize_parameters
    [:name, :code, :email, :place_name, :mailing_address].each do |arg|
      val = @herbarium.send(arg).to_s.strip_html.strip_squeeze
      @herbarium.send("#{arg}=", val)
    end
    @herbarium.description = @herbarium.description.to_s.strip
    @herbarium.code = "" if @herbarium.personal_user_id
  end

  def validate_herbarium!
    validate_name! && validate_location! && validate_personal_herbarium! &&
      validate_admin_personal_user!
  end

  def validate_name!
    if @herbarium.name.blank?
      flash_error(:create_herbarium_name_blank.t)
      return false
    end

    other = Herbarium.where(name: @herbarium.name).first
    return true if !other || other == @herbarium

    if !@herbarium.id # i.e. in create mode
      flash_error(:create_herbarium_duplicate_name.t(name: @herbarium.name))
      false
    else
      @herbarium = perform_or_request_merge(@herbarium, other)
    end
  end

  def validate_location!
    return true if @herbarium.place_name.blank?

    @herbarium.location =
      Location.where(name: @herbarium.place_name).
      or(Location.where(scientific_name: @herbarium.place_name)).first
    # Will redirect to create location if not found.
    true
  end

  def validate_personal_herbarium!
    return true  if in_admin_mode? || @herbarium.personal != "1"
    return false if already_have_personal_herbarium!
    return false if cant_make_this_personal_herbarium!

    @herbarium.personal_user_id = @user.id
    @herbarium.add_curator(@user)
    true
  end

  def validate_admin_personal_user!
    return true unless in_admin_mode?
    return true if nonpersonal!

    name = @herbarium.personal_user_name
    name.sub!(/\s*<(.*)>$/, "")
    user = User.find_by(login: name)
    unless user
      flash_error(
        :runtime_no_match_name.t(type: :user,
                                 value: @herbarium.personal_user_name)
      )
      return false
    end
    return true if user.personal_herbarium == @herbarium
    return false if flash_personal_herbarium?(user)

    flash_notice(
      :edit_herbarium_successfully_made_personal.t(user: user.login)
    )
    @herbarium.curators.clear
    @herbarium.add_curator(user)
    @herbarium.personal_user_id = user.id
  end

  # Return true/false if @herbarium nonpersonal/personal,
  # making it nonpersonal & flashing message if possible
  def nonpersonal!
    return false if @herbarium.personal_user_name.present?
    return true if @herbarium.personal_user_id.nil?

    flash_notice(:edit_herbarium_successfully_made_nonpersonal.t)
    @herbarium.personal_user_id = nil
    @herbarium.curators.clear
    true
  end

  def flash_personal_herbarium?(user)
    return false if user.personal_herbarium.blank?

    flash_error(
      :edit_herbarium_user_already_has_personal_herbarium.t(
        user: user.login, herbarium: user.personal_herbarium.name
      )
    )
    true
  end

  def already_have_personal_herbarium!
    other = @user.personal_herbarium
    return false if !other || other == @herbarium

    flash_error(:create_herbarium_personal_already_exists.t(name: other.name))
    true
  end

  def cant_make_this_personal_herbarium!
    return false if @herbarium.new_record? || @herbarium.can_make_personal?

    flash_error(:edit_herbarium_cant_make_personal.t)
    true
  end

  def notify_admins_of_new_herbarium
    subject = "New Herbarium"
    content = "User created a new herbarium:\n" \
              "Name: #{@herbarium.name} (#{@herbarium.code})\n" \
              "User: #{@user.id}, #{@user.login}, #{@user.name}\n" \
              "Obj: #{@herbarium.show_url}\n"
    WebmasterEmail.build(@user.email, content, subject).deliver_now
  end

  def user_can_destroy_herbarium?
    in_admin_mode? ||
      @herbarium.curator?(@user) ||
      @herbarium.curators.empty? && @herbarium.owns_all_records?(@user)
  end

  def redirect_to_create_location_or_referrer_or_show_location
    redirect_to_create_location ||
      redirect_to_referrer ||
      redirect_with_query(herbarium_path(@herbarium))
  end

  def redirect_to_create_location
    return if @herbarium.location || @herbarium.place_name.blank?

    flash_notice(:create_herbarium_must_define_location.t)
    redirect_to(controller: :location, action: :create_location, back: @back,
                where: @herbarium.place_name, set_herbarium: @herbarium.id)
    true
  end

  def herbarium_params
    return {} unless params[:herbarium]

    params.require(:herbarium).
      permit(:name, :code, :email, :mailing_address, :description,
             :place_name, :personal, :personal_user_name)
  end
end
