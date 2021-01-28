# frozen_string_literal: true

# Controls viewing and modifying herbaria.
class HerbariaController < ApplicationController
  # filters
  before_action(
    :login_required,
    only: [:create, :destroy, :edit, :new, :update]
  )
  before_action(
    :store_location,
    only: [:create, :edit, :index, :new, :show, :update]
  )
  before_action(
    :pass_query_params,
    only: [:create, :destroy, :edit, :new, :show, :update]
  )
  before_action(
    :keep_track_of_referrer,
    only: [:create, :destroy, :edit, :new, :update]
  )

  # Old MO Action (method)        New "Normalized" Action (method)
  # ----------------------        --------------------------------
  # create_herbarium (get)        new
  # create_herbarium (post)       create
  # delete_curator (delete)       Herbaria::Curators#destroy
  # destroy_herbarium             destroy
  # edit_herbarium (get)          edit
  # edit_herbarium (post)         update
  # herbarium_search (get)        Herbaria::Searches#index (get)
  # index (get)                   Herbaria::Nonpersonals#index (get)
  # index_herbarium (get)         Herbaria::Filtereds#index (get)
  # list_herbaria (get)           index
  # merge_herbaria (get)          Herbaria::Merges#new (get)
  # next_herbarium (get)          next
  # prev_herbarium (get)          prev
  # request_to_be_curator (get)   Herbaria::CuratorRequest#new
  # request_to_be_curator (post)  Herbaria::CuratorRequest#create
  # show_herbarium (get)          show
  # show_herbarium (post)         Herbaria::Curators#create

  # ---------- Actions to Display data (index, show, etc.) ---------------------

  # List all herbaria
  def index
    query = create_query(:Herbarium, :all, by: :name)
    show_selected_herbaria(query, always_index: true)
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
    return unless validate_herbarium!

    @herbarium.save
    @herbarium.add_curator(@user) if @herbarium.personal_user
    notify_admins_of_new_herbarium unless @herbarium.personal_user
    redirect_to_create_location_or_referrer_or_show_location
  end

  def update
    return unless (@herbarium = find_or_goto_index(Herbarium, params[:id]))
    return unless make_sure_can_edit!

    # update_herbarium
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
        redirect_with_query(herbaria_filtereds_path(id: @herbarium.try(&:id)))
    else
      flash_error(:permission_denied.t)
      redirect_to_referrer || redirect_with_query(herbarium_path(@herbarium))
    end
  end

  # ========== Non=standard REST Actions =======================================

  # ---------- Display data

  # list nonpersonal herbaria (herbarium.personal_id == nil)
  def nonpersonal
    query = create_query(:Herbarium, :nonpersonal, by: :code_then_name)
    show_selected_herbaria(query, always_index: true)
  end

  def next
    redirect_to_next_object(:next, Herbarium, params[:id].to_s)
  end

  def prev
    redirect_to_next_object(:prev, Herbarium, params[:id].to_s)
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
    [:name, :code, :email, :place_name, :mailing_address].each do |arg|
      val = @herbarium.send(arg).to_s.strip_html.strip_squeeze
      @herbarium.send("#{arg}=", val)
    end
    @herbarium.description = @herbarium.description.to_s.strip
    @herbarium.code = "" if @herbarium.personal_user_id
  end

  def validate_herbarium!
    validate_name! &&
      validate_location! &&
      validate_personal_herbarium! &&
      validate_admin_personal_user!
  end

  def validate_name!
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
      # Location.find_by_name_or_reverse_name(@herbarium.place_name)
      Location.where(name: @herbarium.place_name).
      or(Location.where(scientific_name: @herbarium.place_name)).first
    # Will redirect to create location if not found.
    true
  end

  def validate_personal_herbarium!
    return true  if in_admin_mode?
    return true  if @herbarium.personal != "1"
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
