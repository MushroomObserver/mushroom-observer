# Controls viewing and modifying herbaria.
class HerbariumController < ApplicationController
  before_action :login_required, except: [
    :index,
    :index_herbarium,
    :list_herbariums,
    :herbarium_search,
    :show_herbarium
  ]

  # ----------------------------
  #  Indexes
  # ----------------------------

  def index # :nologin:
    store_location
    @herbaria = Herbarium.order(:name)
  end

  # Displays selected Herbarium's (based on current Query).
  def index_herbarium # :nologin: :norobots:
    query = find_or_create_query(:Herbarium, by: params[:by])
    show_selected_herbarium(query, id: params[:id].to_s)
  end

  # Show list of herbaria.
  def list_herbariums # :nologin:
    store_location
    query = create_query(:Herbarium, :all, by: :name)
    show_selected_herbaria(query)
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
      num_per_page: 100
    }.merge(args)

    @links ||= []
    @links << [:create_herbarium.l,
               { controller: :herbarium, action: :create_herbarium }]

    # Add some alternate sorting criteria.
    args[:sorting_links] = [
      ["name",        :sort_by_title.t],
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
    return if !@user || !@herbarium.is_curator?(@user) && !in_admin_mode?
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
    @herbarium = find_or_goto_index(Herbarium, params[:id])
    return unless @herbarium
    return unless make_sure_can_edit!
    if request.method == "GET"
      @herbarium.place_name = @herbarium.location.try(&:name)
    elsif request.method == "POST"
      post_edit_herbarium
    else
      redirect_back_or_default("/")
    end
  end

  def post_create_herbarium
    @herbarium = Herbarium.new(whitelisted_herbarium_params)
    normalize_parameters
    if validate_name! &&
       validate_location! &&
       validate_personal_herbarium!
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
       validate_location!
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
  end

  def validate_name!
    other = Herbarium.where(name: @herbarium.name).first
    return true if !other || other == @herbarium
    if !@herbarium.id # i.e. in create mode
      flash_error(:create_herbarium_duplicate_name.t(name: @herbarium.name))
      return false
    elsif in_admin_mode?
      @herbarium = @herbarium.merge(other)
      return true
    else
      redirect_with_query(controller: :observer, action: :email_merge_request,
                          type: :Herbarium, old_id: @herbarium.id,
                          new_id: other.id)
      return false
    end
  end

  def validate_location!
    return true if @herbarium.place_name.blank?
    @herbarium.location =
      Location.find_by_name_or_reverse_name(@herbarium.place_name)
    true
  end

  def validate_personal_herbarium!
    return true unless @herbarium.personal == "1"
    other = @user.personal_herbarium
    if other
      flash_error(:create_herbarium_personal_already_exists.t(name: other.name))
      return false
    else
      @herbarium.personal_user = @user
    end
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
    if !herbarium.is_curator?(@user) && !in_admin_mode?
      flash_error(:permission_denied.t)
    elsif user && herbarium.is_curator?(user)
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
             :place_name, :personal)
  end
end
