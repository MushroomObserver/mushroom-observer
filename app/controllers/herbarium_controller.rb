# Controls viewing and modifying herbaria.
class HerbariumController < ApplicationController
  before_action :login_required, except: [
    :index,
    :index_herbarium,
    :list_herbaria,
    :herbarium_search,
    :show_herbarium
  ]

  # ----------------------------
  #  Indexes
  # ----------------------------

  # Displays selected Herbarium's (based on current Query).
  def index_herbarium # :nologin: :norobots:
    query = find_or_create_query(:Herbarium, by: params[:by])
    show_selected_herbaria(query, id: params[:id].to_s, always_index: true)
  end

  def index # :nologin:
    store_location
    query = create_query(:Herbarium, :all,
                         where: "herbaria.personal_user_id IS NULL",
                         by: :code_then_name)
    @title = :herbarium_index_title.t
    @links = [[:herbarium_index_list_all_herbaria.l,
               { controller: :herbarium, action: :list_herbaria }]]
    @no_user_column = true
    show_selected_herbaria(query, always_index: true)
  end

  # Show list of herbaria.
  def list_herbaria # :nologin:
    store_location
    query = create_query(:Herbarium, :all, by: :name)
    @links = [[:herbarium_index_nonpersonal_herbaria.l,
               { controller: :herbarium, action: :index }]]
    show_selected_herbaria(query, always_index: true)
  end

  # Display list of Herbaria whose text matches a string pattern.
  def herbarium_search # :nologin: :norobots:
    pattern = params[:pattern].to_s
    if pattern.match(/^\d+$/) &&
       (herbarium = Herbarium.safe_find(pattern))
      redirect_to(action: "show_herbarium", id: herbarium.id)
    else
      query = create_query(:Herbarium, :pattern_search, pattern: pattern)
      show_selected_herbaria(query)
    end
  end

  # Show selected list of herbaria.
  def show_selected_herbaria(query, args = {})
    args = {
      action: :list_herbaria,
      letters: "herbaria.name",
      num_per_page: 100,
      include: [:curators, :herbarium_records, :personal_user]
    }.merge(args)

    @links ||= []
    @links << [:create_herbarium.l,
               { controller: :herbarium, action: :create_herbarium }]

    # If user clicks "merge" on an herbarium, it reloads the page and asks
    # them to click on the destination herbarium to merge it with.
    @merge = Herbarium.safe_find(params[:merge])

    # Add some alternate sorting criteria.
    args[:sorting_links] = [
      ["records",     :sort_by_records.t],
      ["code",        :sort_by_code.t],
      ["name",        :sort_by_name.t],
      ["created_at",  :sort_by_created_at.t],
      ["updated_at",  :sort_by_updated_at.t]
    ]

    show_index_of_objects(query, args)
  end

  # ----------------------------
  #  Show herbarium
  # ----------------------------

  def show_herbarium # :nologin:
    store_location
    pass_query_params
    @canonical_url = Herbarium.show_url(params[:id])
    @herbarium = find_or_goto_index(Herbarium, params[:id])
    return if request.method != "POST"
    return if !@user || !@herbarium.curator?(@user) && !in_admin_mode?
    login = params[:add_curator].to_s.sub(/ <.*/, "")
    user = User.find_by_login(login)
    if user
      @herbarium.add_curator(user)
    else
      flash_error(:show_herbarium_no_user.t(login: login))
    end
  end

  def next_herbarium # :nologin: :norobots:
    redirect_to_next_object(:next, Herbarium, params[:id].to_s)
  end

  def prev_herbarium # :nologin: :norobots:
    redirect_to_next_object(:prev, Herbarium, params[:id].to_s)
  end

  # ----------------------------
  #  Create and edit herbarium
  # ----------------------------

  def create_herbarium # :norobots:
    store_location
    pass_query_params
    if request.method == "GET"
      @herbarium = Herbarium.new
    elsif request.method == "POST"
      post_create_herbarium
    else
      redirect_back_or_default("/")
    end
  end

  def edit_herbarium # :norobots:
    store_location
    pass_query_params
    @herbarium = find_or_goto_index(Herbarium, params[:id])
    return unless @herbarium
    return unless make_sure_can_edit!
    if request.method == "GET"
      @herbarium.place_name         = @herbarium.location.try(&:name)
      @herbarium.personal           = @herbarium.personal_user_id.present?
      @herbarium.personal_user_name = @herbarium.personal_user.try(&:login)
    elsif request.method == "POST"
      post_edit_herbarium
    else
      redirect_back_or_default("/")
    end
  end

  def merge_herbaria # :norobots:
    this = find_or_goto_index(Herbarium, params[:this]) || return
    that = find_or_goto_index(Herbarium, params[:that]) || return
    result = perform_or_request_merge(this, that) || return
    redirect_to(result.show_link_args)
  end

  def post_create_herbarium
    @herbarium = Herbarium.new(whitelisted_herbarium_params)
    normalize_parameters
    if validate_name! &&
       validate_location! &&
       validate_personal_herbarium! &&
       validate_admin_personal_user!
      @herbarium.save
      @herbarium.add_curator(@user) if @herbarium.personal_user
      notify_admins_of_new_herbarium unless @herbarium.personal_user
      redirect_to_create_location || redirect_to_show_herbarium
    end
  end

  def post_edit_herbarium
    @herbarium.attributes = whitelisted_herbarium_params
    normalize_parameters
    if validate_name! &&
       validate_location! &&
       validate_personal_herbarium! &&
       validate_admin_personal_user!
      @herbarium.save
      redirect_to_create_location || redirect_to_show_herbarium
    end
  end

  def make_sure_can_edit!
    return true if in_admin_mode? || @herbarium.can_edit?
    flash_error :permission_denied.t
    redirect_to(@herbarium.show_link_args)
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

  def validate_name!
    other = Herbarium.where(name: @herbarium.name).first
    return true if !other || other == @herbarium
    if !@herbarium.id # i.e. in create mode
      flash_error(:create_herbarium_duplicate_name.t(name: @herbarium.name))
      return false
    else
      @herbarium = perform_or_request_merge(@herbarium, other)
    end
  end

  def validate_location!
    return true if @herbarium.place_name.blank?
    @herbarium.location =
      Location.find_by_name_or_reverse_name(@herbarium.place_name)
    # Will redirect to create location if not found.
    true
  end

  def validate_personal_herbarium!
    return true  if in_admin_mode?
    return true  if @herbarium.personal != "1"
    return false if already_have_personal_herbarium!
    return false if cant_make_this_personal_herbarium!
    @herbarium.personal_user_id = @user.id
    true
  end

  def validate_admin_personal_user!
    return true unless in_admin_mode?
    if @herbarium.personal_user_name.blank?
      return true if @herbarium.personal_user_id.nil?
      flash_notice(:edit_herbarium_successfully_made_nonpersonal.t)
      @herbarium.personal_user_id = nil
      @herbarium.curators.clear
      return true
    end
    user = User.find_by_login(@herbarium.personal_user_name)
    unless user
      flash_error(:runtime_no_match_name.t(
                    type: :user, value: @herbarium.personal_user_name
                  ))
      return false
    end
    return true if user.personal_herbarium == @herbarium
    if user.personal_herbarium.present?
      flash_error(:edit_herbarium_user_already_has_personal_herbarium.t(
                    user: user.login, herbarium: user.personal_herbarium.name
                  ))
      return false
    end
    flash_notice(:edit_herbarium_successfully_made_personal.t(user: user.login))
    @herbarium.curators.clear
    @herbarium.add_curator(user)
    @herbarium.personal_user_id = user.id
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

  def perform_or_request_merge(this, that)
    if in_admin_mode? || this.can_merge_into?(that)
      perform_merge(this, that)
    else
      request_merge(this, that)
    end
  end

  def perform_merge(this, that)
    old_name = this.name_was
    result = this.merge(that)
    flash_notice(:runtime_merge_success.t(type: :herbarium,
                                          this: old_name,
                                          that: result.name))
    result
  end

  def request_merge(this, that)
    redirect_with_query(controller: :observer, action: :email_merge_request,
                        type: :Herbarium, old_id: this.id, new_id: that.id)
    false
  end

  def redirect_to_create_location
    return if @herbarium.location || @herbarium.place_name.blank?
    flash_notice(:create_herbarium_must_define_location.t)
    redirect_to(controller: :location, action: :create_location,
                where: @herbarium.place_name, set_herbarium: @herbarium.id)
    true
  end

  def redirect_to_show_herbarium
    redirect_to(@herbarium.show_link_args)
  end

  def notify_admins_of_new_herbarium
    subject = "New Herbarium"
    content = "User created a new herbarium:\n" \
              "Name: #{@herbarium.name} (#{@herbarium.code})\n" \
              "User: #{@user.id}, #{@user.login}, #{@user.name}\n" \
              "Obj: #{@herbarium.show_url}\n"
    WebmasterEmail.build(@user.email, content, subject).deliver_now
  end

  # ----------------------------
  #  Curators
  # ----------------------------

  def delete_curator
    herbarium = find_or_goto_index(Herbarium, params[:id])
    return unless herbarium
    user = User.safe_find(params[:user])
    if !herbarium.curator?(@user) && !in_admin_mode?
      flash_error(:permission_denied.t)
    elsif user && herbarium.curator?(user)
      herbarium.delete_curator(user)
    end
    redirect_back_or_default(herbarium.show_link_args)
  end

  def request_to_be_curator
    @herbarium = find_or_goto_index(Herbarium, params[:id])
    return unless @herbarium && request.method == "POST"
    subject = "Herbarium Curator Request"
    content =
      "User: ##{@user.id}, #{@user.login}, #{@user.show_url}\n" \
      "Herbarium: #{@herbarium.name}, #{@herbarium.show_url}\n" \
      "Notes: #{params[:notes]}"
    WebmasterEmail.build(@user.email, content, subject).deliver_now
    flash_notice(:show_herbarium_request_sent.t)
  end

  ##############################################################################

  private

  def whitelisted_herbarium_params
    return {} unless params[:herbarium]
    params.require(:herbarium).
      permit(:name, :code, :email, :mailing_address, :description,
             :place_name, :personal, :personal_user_name)
  end
end
