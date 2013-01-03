class ConferenceController < ApplicationController
  before_filter :login_required, :except => [
    :show_event,
    :index,
    :register,
    :verify,
  ]

  # TODO:
  # Need to watch for non-verified registrations
  # Links to events
  
  # Have users own ConferenceEvents rather than admin
  # Owners can delete ConferenceEvents
  
  # Creating a conference event should be RESTful, but I'm not sure what our conventions are at this point
  def show_event # :nologin:
    store_location
    @event = ConferenceEvent.find(params[:id].to_s)
    @registration_count = @event.how_many
  end

  def index # :nologin:
    store_location
    @events = ConferenceEvent.find(:all)
  end
  
  def create_event # :norobots:
    if is_in_admin_mode? # Probably should be expanded to any MO user
      if request.method == :post
        event = ConferenceEvent.new(params[:event])
        event.save
        redirect_to(:action => 'show_event', :id => event.id)
      end
    else
      flash_error(:create_event_not_allowed.l)
      redirect_to(:action => 'index')
    end
  end
  
  def edit_event # :norobots:
    # Expand to any MO user, but make them owned and editable only by that user or an admin
    if is_in_admin_mode?
      if request.method == :post
        event = ConferenceEvent.find(params[:id].to_s)
        event.attributes = params[:event]
        event.save
        redirect_to(:action => 'show_event', :id => event.id)
      else
        @event = ConferenceEvent.find(params[:id].to_s)
      end
    else
      flash_error(:edit_event_not_allowed.l)
      redirect_to(:action => 'index')
    end
  end
  
  def register # :nologin: :norobots:
    store_location
    event = ConferenceEvent.find(params[:id].to_s)
    if request.method == :post
      registration = find_previous_registration(params)
      if registration.nil?
        registration = ConferenceRegistration.new(params[:registration])
        registration.conference_event = event
        registration.save
        flash_notice(:register_success.l(:name => event.name, :how_many => registration.how_many))
        QueuedEmail::Registered.create_email(@user, registration)
      end
      redirect_to(:action => 'show_event', :id => event.id)
    else
      @event = event
    end
  end

  def find_previous_registration(params)
    result = nil
    all_registrations = ConferenceRegistration.find(:all,
      :conditions => "email = '#{params[:registration][:email]}' and conference_event_id = #{params[:id]}")
    if not all_registrations.empty?
      result = all_registrations[0]
      before = result.describe
      flash_warning(:register_update_warning.t(:description => before))
      result.update_from_params(params[:registration])
      result.save
      QueuedEmail::UpdateRegistration.create_email(@user, result, before)
    end
    return result
  end
  
  def list_registrations # :norobots:
    if is_in_admin_mode?
      @event = ConferenceEvent.find(params[:id].to_s)
      @hello = "Hello"
    else
      flash_error(:list_registrations_not_allowed.l)
      redirect_to(:action => 'index')
    end
  end
  
  def verify # :nologin: :norobots:
    registration = ConferenceRegistration.find(params[:id].to_s)
    if registration.verified == nil
      registration.verified = Time.now
      registration.save
      event = registration.conference_event
      flash_notice(:conference_verify_success.l(:event => event.name, :registrant => registration.name, :how_many => registration.how_many))
      redirect_to(:action => 'show_event', :id => event.id)
    else
      flash_warning(:conference_verify_warning.l)
      redirect_to(:action => :index)
    end
  end
end
