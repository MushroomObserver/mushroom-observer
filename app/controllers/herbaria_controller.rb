# frozen_string_literal: true

# Actions
# -------
# create (post)
# destroy (delete)
# edit (get)
# index (get)                      (default) list query results
# index (get, pattern: present)    list Herbaria matching a string pattern
# index (get, nonpersonal: true)   list institutional Herbaria registered in IH
# index (get)                       list all Herbaria
# new (get)
# show (get)                       show one herbarium
# show { flow: :prev } (get)       show next herbarium in search results
# show { flow: :prev } (get)       show previous herbarium in search results
# update (patch)
# Herbaria::Curators#create (post)
# Herbaria::Curators#destroy (delete)
# Herbaria::Merges#create (post)
# Herbaria::CuratorRequest#new (get)
# Herbaria::CuratorRequest#create (post)

# Table: legacy Herbariums actions vs updated Herbaria actions
#
# legacy Herbarium action (method)  updated Herbaria action (method)
# --------------------------------  ---------------------------------
# create_herbarium (get)            new (get)
# create_herbarium (post)           create (post)
# delete_curator (delete)           Herbaria::Curators#destroy (delete)
# destroy_herbarium (delete)        destroy (delete)
# edit_herbarium (get)              edit (get)
# edit_herbarium (post)             update (patch)
# herbarium_search (get)            index (get, pattern: present)
# index (get)                       index (get, nonpersonal: true)
# index_herbarium (get)             index (get) - lists query results
# list_herbaria (get)               index (get) - all herbaria
# *merge_herbaria (get)             Herbaria::Merges#create (post)
# *next_herbarium (get)             show { flow: :next } (get))
# *prev_herbarium (get)             show { flow: :prev } (get)
# request_to_be_curator (get)       Herbaria::CuratorRequest#new (get)
# request_to_be_curator (post)      Herbaria::CuratorRequest#create (post)
# show_herbarium (get)              show (get)
# show_herbarium (post)             Herbaria::Curators#create (post)
# * == legacy action is not redirected
# See https://tinyurl.com/ynapvpt7

# View and modify Herbaria (displayed as "Fungaria")
class HerbariaController < ApplicationController # rubocop:disable Metrics/ClassLength
  include ::Locationable

  before_action :login_required
  # only: [:create, :destroy, :edit, :new, :update]
  before_action :store_location, only: [:create, :edit, :new, :show, :update]
  before_action :pass_query_params, only: [
    :create, :destroy, :edit, :new, :show, :update
  ]
  before_action :keep_track_of_referrer, only: [:destroy, :edit, :new]

  ##############################################################################
  # INDEX

  # Display list of selected herbaria, based on params
  #   params[:pattern].present? - Herbaria based on Pattern Search
  #   [:nonpersonal].blank? - all Herbaria, regardless of query
  #   [:nonpersonal].present? - all nonpersonal (institutional) Herbaria
  #   sorted_index - Herbaria based on current Query
  #                         (Sort links land on this action)
  #
  def index
    set_merge_ivar if params[:merge]
    build_index_with_query
  end

  private

  # If user clicks "merge" on an herbarium, it reloads the page and asks
  # them to click on the destination herbarium to merge it with.
  def set_merge_ivar
    @merge = Herbarium.safe_find(params[:merge])
  end

  def default_sort_order
    ::Query::Herbaria.default_order # :name
  end

  def index_active_params
    [:pattern, :nonpersonal, :by, :q, :id].freeze
  end

  # Show selected list, based on current Query.
  # (Linked from show template, next to "prev" and "next"... or will be.)
  # Passes explicit :by param to affect title (only).
  def sorted_index_opts
    sorted_by = params[:by] || default_sort_order
    super.merge(query_args: { order_by: sorted_by })
  end

  def nonpersonal
    store_location
    query = create_query(
      :Herbarium, nonpersonal: true, order_by: :code_then_name
    )
    [query, { always_index: true }]
  end

  def index_display_opts(opts, _query)
    { letters: true,
      num_per_page: 100,
      include: [:curators, :herbarium_records, :personal_user] }.merge(opts)
  end

  public

  ##############################################################################
  #
  # Display a single herbarium, based on :flow params
  # :flow is added in _prev_next_page partial, ApplicationHelper#link_next
  def show
    case params[:flow]
    when "next"
      redirect_to_next_object(:next, Herbarium, params[:id].to_s)
    when "prev"
      redirect_to_next_object(:prev, Herbarium, params[:id].to_s)
    else
      @canonical_url = herbarium_url(params[:id])
      @herbarium = find_or_goto_index(Herbarium, params[:id])
    end
  end

  # ---------- Actions to Display forms -- (new, edit, etc.) -------------------

  def new
    @herbarium = Herbarium.new
    respond_to do |format|
      format.turbo_stream { render_modal_herbarium_form }
      format.html
    end
  end

  def edit
    @herbarium = find_or_goto_index(Herbarium, params[:id])
    return unless @herbarium && make_sure_can_edit!

    set_up_herbarium_for_edit
    respond_to do |format|
      format.turbo_stream { render_modal_herbarium_form }
      format.html
    end
  end

  def set_up_herbarium_for_edit
    @herbarium.place_name         = @herbarium.location.try(&:name)
    @herbarium.personal           = @herbarium.personal_user_id.present?
    @herbarium.personal_user_name = @herbarium.personal_user.try(&:login)
  end

  def render_modal_herbarium_form
    render(
      partial: "shared/modal_form",
      locals: { title: modal_title, identifier: modal_identifier,
                user: @user, form: "herbaria/form",
                form_locals: { local: false, action: modal_form_action } }
    ) and return
  end

  def modal_identifier
    case action_name
    when "new", "create"
      "herbarium"
    when "edit", "update"
      "herbarium_#{@herbarium.id}"
    end
  end

  def modal_title
    case action_name
    when "new", "create"
      helpers.new_page_title(:new_object, :HERBARIUM)
    when "edit", "update"
      helpers.edit_page_title(:HERBARIUM_RECORD.l, @herbarium)
    end
  end

  def modal_form_action
    case action_name
    when "new", "create" then :create
    when "edit", "update" then :update
    end
  end

  # ---------- Actions to Modify data: (create, update, destroy, etc.) ---------

  def create
    @herbarium = Herbarium.new(herbarium_params)
    normalize_parameters
    create_location_object_if_new(@herbarium)
    try_to_save_location_if_new(@herbarium)
    return render(:new) unless validate_herbarium! && !@any_errors

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
    create_location_object_if_new(@herbarium)
    try_to_save_location_if_new(@herbarium)
    return unless validate_herbarium! && !@any_errors

    @herbarium.save
    redirect_to_create_location_or_referrer_or_show_location
  end

  def destroy
    return unless (@herbarium = find_or_goto_index(Herbarium, params[:id]))

    if user_can_destroy_herbarium?
      @herbarium.destroy
      redirect_to_referrer ||
        redirect_with_query(herbarium_path(@herbarium.try(&:id)))
    else
      flash_error(:permission_denied.t)
      redirect_to_referrer || redirect_with_query(herbarium_path(@herbarium))
    end
  end

  ##############################################################################

  private

  include Herbaria::SharedPrivateMethods

  def make_sure_can_edit!
    return true if in_admin_mode? || @herbarium.can_edit?

    flash_error(:permission_denied.t)
    redirect_to_referrer || redirect_with_query(herbarium_path(@herbarium))
    false
  end

  def normalize_parameters
    [:name, :code, :email, :place_name, :mailing_address].
      each do |arg|
        val = @herbarium.send(arg).to_s.strip_html.strip_squeeze
        @herbarium.send(:"#{arg}=", val)
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

    dest = Herbarium.where(name: @herbarium.name).first
    return true if !dest || dest == @herbarium

    if @herbarium.id
      @herbarium = perform_or_request_merge(@herbarium, dest)
    else # i.e. in create mode
      flash_error(:create_herbarium_duplicate_name.t(name: @herbarium.name))
      false
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
    update_personal_herbarium(user)
  end

  def update_personal_herbarium(user)
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
    QueuedEmail::Webmaster.create_email(
      @user,
      subject: "New Herbarium",
      content: "User created a new herbarium:\n" \
               "Name: #{@herbarium.name} (#{@herbarium.code})\n" \
               "User: #{@user.id}, #{@user.login}, #{@user.name}\n" \
               "Obj: #{@herbarium.show_url}\n"
    )
  end

  def user_can_destroy_herbarium?
    in_admin_mode? || @herbarium.curator?(@user) ||
      @herbarium.curators.empty? && @herbarium.owns_all_records?(@user)
  end

  def redirect_to_create_location_or_referrer_or_show_location
    redirect_to_create_location || redirect_to_referrer ||
      show_modal_flash_or_show_herbarium
  end

  def redirect_to_create_location
    return if @herbarium.location || @herbarium.place_name.blank?

    flash_notice(:create_herbarium_must_define_location.t)
    redirect_to(new_location_path(back: @back,
                                  where: @herbarium.place_name,
                                  set_herbarium: @herbarium.id))
    true
  end

  # this updates both the form and the flash
  def reload_herbarium_modal_form_and_flash
    render(
      partial: "shared/modal_form_reload",
      locals: { identifier: modal_identifier,
                user: @user, form: "herbaria/form" }
    ) and return true
  end

  # What to do if the save succeeds
  def show_modal_flash_or_show_herbarium
    respond_to do |format|
      format.html do
        redirect_with_query(herbarium_path(@herbarium)) and return
      end
      format.turbo_stream do
        # Context here is the obs form.
        flash_notice(
          :runtime_created_name.t(type: :herbarium, value: @herbarium.name)
        )
        flash_notice(
          :runtime_added_to.t(type: :herbarium, name: :observation)
        )
        render(partial: "herbaria/update_observation") and return
      end
    end
  end

  def herbarium_params
    return {} unless params[:herbarium]

    params.require(:herbarium).
      permit(:name, :code, :email, :mailing_address,
             :description, :location_id,
             :place_name, :personal, :personal_user_name)
  end
end
