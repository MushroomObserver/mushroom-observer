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

  # Sort options for the index page. `nonpersonal` queries get a
  # different subset (records / curator / code / name + create/update);
  # full queries get every key. Read by `add_sorter` in the view.
  # Each key must resolve to `Herbarium.order_by_<key>`.
  def index_sort_options
    if @query&.params&.dig(:nonpersonal)
      nonpersonal_index_sort_options
    else
      full_index_sort_options
    end
  end

  private

  # Phlex action template — explicit render per the conversion rule.
  def render_index_view
    render(Views::Controllers::Herbaria::Index.new(
             query: @query, pagination_data: @pagination_data,
             objects: @objects, merge: @merge
           ))
  end

  def full_index_sort_options
    [
      ["records",    :sort_by_records.t],
      ["curator",    :sort_by_curator.t],
      ["code",       :sort_by_code.t],
      ["name",       :sort_by_name.t],
      ["user",       :sort_by_user.t],
      ["created_at", :sort_by_created_at.t],
      ["updated_at", :sort_by_updated_at.t]
    ].freeze
  end

  # Nonpersonal variant is the full list minus `user` only (NOT
  # `curator` — institutional herbaria can still have curators,
  # so sorting by curator is meaningful in the nonpersonal view).
  # Matches the legacy `nonpersonal_herbaria_index_sorts` exactly.
  def nonpersonal_index_sort_options
    # rubocop:disable Style/HashExcept
    # `except` mistakenly suggested here — this is an Array of
    # [key, label] tuples, not a Hash. `reject` is correct.
    full_index_sort_options.reject { |key, _| key == "user" }.freeze
    # rubocop:enable Style/HashExcept
  end

  # If user clicks "merge" on an herbarium, it reloads the page and asks
  # them to click on the destination herbarium to merge it with.
  def set_merge_ivar
    @merge = Herbarium.safe_find(params[:merge])
  end

  def default_sort_order
    ::Query::Herbaria.default_order # :records
  end

  def index_active_params
    [:pattern, :nonpersonal, :by, :q, :id].freeze
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
    flow = params[:flow]
    return redirect_to_next_object(flow.to_sym, Herbarium, params[:id].to_s) \
      if %w[next prev].include?(flow)

    render_herbarium_show
  end

  def render_herbarium_show
    @canonical_url = herbarium_url(params[:id])
    return unless (@herbarium = find_or_goto_index(Herbarium, params[:id]))

    render(Views::Controllers::Herbaria::Show.new(herbarium: @herbarium))
  end

  # ---------- Actions to Display forms -- (new, edit, etc.) -------------------

  def new
    @herbarium = Herbarium.new
    respond_to do |format|
      format.turbo_stream { render_modal_herbarium_form }
      format.html do
        render(Views::Controllers::Herbaria::New.new(
                 herbarium: @herbarium, user: @user
               ))
      end
    end
  end

  def edit
    @herbarium = find_or_goto_index(Herbarium, params[:id])
    return unless @herbarium && make_sure_can_edit!

    set_up_herbarium_for_edit
    respond_to do |format|
      format.turbo_stream { render_modal_herbarium_form }
      format.html do
        render(Views::Controllers::Herbaria::Edit.new(
                 herbarium: @herbarium, user: @user, top_users: @top_users
               ))
      end
    end
  end

  def set_up_herbarium_for_edit
    @herbarium.place_name         = @herbarium.location.try(&:name)
    @herbarium.personal           = @herbarium.personal_user_id.present?
    @herbarium.personal_user_name = @herbarium.personal_user.try(&:login)
    return unless in_admin_mode?

    @top_users = User.top_users_for_herbarium(@herbarium)
  end

  def render_modal_herbarium_form
    render(Components::Modal::TurboForm.new(
             identifier: modal_identifier,
             title: modal_title,
             user: @user,
             model: @herbarium,
             form_locals: { user: @user,
                            location: @herbarium.location,
                            top_users: @top_users }
           ), layout: false)
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
      :new_object.t(type: :HERBARIUM)
    when "edit", "update"
      render_to_string(Views::Layouts::Header::ObjectTitle.new(
                         object: @herbarium, mode: :edit,
                         title: :HERBARIUM_RECORD.l
                       ))
    end
  end

  # ---------- Actions to Modify data: (create, update, destroy, etc.) ---------

  def create
    @herbarium = Herbarium.new(herbarium_params)
    normalize_parameters
    create_location_object_if_new(@herbarium)
    try_to_save_location_if_new(@herbarium)
    return reload_form(:new) unless validate_herbarium! && !@any_errors

    unless @herbarium.save
      flash_object_errors(@herbarium)
      return reload_form(:new)
    end
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
    return reload_form(:edit) unless validate_herbarium! && !@any_errors

    unless @herbarium.save
      flash_object_errors(@herbarium)
      return reload_form(:edit)
    end
    redirect_to_create_location_or_referrer_or_show_location
  end

  def destroy
    return unless (@herbarium = find_or_goto_index(Herbarium, params[:id]))

    if user_can_destroy_herbarium?
      @herbarium.destroy
      redirect_to_referrer || redirect_to(herbarium_path(@herbarium.try(&:id)))
    else
      flash_error(:permission_denied.t)
      redirect_to_referrer || redirect_to(herbarium_path(@herbarium))
    end
  end

  ##############################################################################

  private

  include Herbaria::SharedPrivateMethods

  def make_sure_can_edit!
    return true if in_admin_mode? || @herbarium.can_edit?(@user)

    flash_error(:permission_denied.t)
    redirect_to_referrer || redirect_to(herbarium_path(@herbarium))
    false
  end

  def normalize_parameters
    [:name, :code, :email, :place_name, :mailing_address].
      each do |arg|
        val = @herbarium.send(arg).to_s.strip_html.strip_squeeze
        @herbarium.send(:"#{arg}=", val)
      end
    @herbarium.description = @herbarium.description.to_s.strip
    # Use nil instead of empty string for code (DB has partial unique index)
    @herbarium.code = @herbarium.code.presence
    @herbarium.code = nil if @herbarium.personal_user_id
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
    # Migrated from QueuedEmail::Webmaster to ActionMailer + ActiveJob.
    body = "User created a new herbarium:\n" \
           "Name: #{@herbarium.name} (#{@herbarium.code})\n" \
           "User: #{@user.id}, #{@user.login}, #{@user.name}\n" \
           "Obj: #{@herbarium.show_url}\n"
    message = WebmasterMailer.prepend_user(@user, body)
    WebmasterMailer.build(
      sender_email: @user.email,
      subject: "New Herbarium",
      message:
    ).deliver_later
  end

  def user_can_destroy_herbarium?
    in_admin_mode? || @herbarium.curator?(@user) ||
      @herbarium.curators.empty? && @herbarium.owns_all_records?(@user)
  end

  def redirect_to_create_location_or_referrer_or_show_location
    # Turbo-stream callers (the herbarium-create modal embedded in the
    # obs form, project pages, etc.) should never get a redirect:
    # we're in a modal that needs to close + update the parent page.
    # `show_modal_flash_or_show_herbarium` dispatches on format and
    # renders `_update_observation.erb` for turbo_stream, which closes
    # the modal and populates the obs-form's herbarium fields.
    return show_modal_flash_or_show_herbarium if request.format.turbo_stream?

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

  # Handle form reload for both HTML and turbo_stream formats
  # Skip if a redirect was already performed (e.g., by request_merge)
  def reload_form(action)
    return if performed?

    respond_to do |format|
      format.turbo_stream { reload_herbarium_modal_form_and_flash }
      format.html { render(phlex_form_view_for(action)) }
    end
  end

  def phlex_form_view_for(action)
    case action
    when :new
      Views::Controllers::Herbaria::New.new(
        herbarium: @herbarium, user: @user
      )
    when :edit
      Views::Controllers::Herbaria::Edit.new(
        herbarium: @herbarium, user: @user, top_users: @top_users
      )
    end
  end

  # this updates both the form and the flash
  def reload_herbarium_modal_form_and_flash
    render_modal_form_reload(identifier: modal_identifier, form_locals: {
                               model: @herbarium,
                               user: @user,
                               location: @herbarium.location,
                               top_users: @top_users
                             }) and return true
  end

  # Turbo-stream chain emitted from `show_modal_flash_or_show_herbarium`
  # success branch — closes the herbarium-create modal, flashes the
  # success notice into the obs form's `page_flash`, updates the obs
  # form's herbarium-name + herbarium-id inputs to the newly-saved
  # herbarium, and removes the "Create herbarium" button. Inlined
  # from the deleted `herbaria/_update_observation.erb` partial.
  def update_observation_after_herbarium_save_streams
    [
      turbo_stream.close_modal("modal_herbarium"),
      turbo_stream.remove("modal_herbarium"),
      turbo_stream_flash_update,
      # Obs form's herbarium-name field is namespaced under the
      # observation Superform: id is `observation_herbarium_record_*`.
      turbo_stream.update_input(
        "observation_herbarium_record_herbarium_name", @herbarium.name
      ),
      turbo_stream.update_input(
        "observation_herbarium_record_herbarium_id", @herbarium.id
      ),
      turbo_stream.remove("create_herbarium_btn")
    ]
  end

  # What to do if the save succeeds
  def show_modal_flash_or_show_herbarium
    respond_to do |format|
      format.html do
        redirect_to(herbarium_path(@herbarium)) and return
      end
      format.turbo_stream do
        # Context here is the obs form.
        flash_notice(
          :runtime_created_name.t(type: :herbarium, value: @herbarium.name)
        )
        flash_notice(
          :runtime_added_to.t(type: :herbarium, name: :observation)
        )
        render(turbo_stream: update_observation_after_herbarium_save_streams)
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
