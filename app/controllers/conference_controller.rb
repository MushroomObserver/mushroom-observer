class ConferenceController < ApplicationController
  before_action :login_required, except: [
    :show_event,
    :index,
    :register,
    :verify
  ]

  # TODO:
  # Need to watch for non-verified registrations
  # Links to events

  # Have users own ConferenceEvents rather than admin
  # Owners can delete ConferenceEvents

  # Creating a conference event should be RESTful,
  # but I'm not sure what our conventions are at this point
  def show_event # :nologin:
    store_location
    @event = ConferenceEvent.find(params[:id].to_s)
    @registration_count = @event.how_many
  end

  def index # :nologin:
    store_location
    @events = ConferenceEvent.all
  end

  def create_event # :norobots:
    if in_admin_mode? # Probably should be expanded to any MO user
      if request.method == "POST"
        event = ConferenceEvent.new(whitelisted_event_params)
        event.save
        redirect_to(action: "show_event", id: event.id)
      end
    else
      flash_error(:create_event_not_allowed.l)
      redirect_to(action: "index")
    end
  end

  def edit_event # :norobots:
    # Expand to any MO user,
    # but make them owned and editable only by that user or an admin
    if in_admin_mode?
      if request.method == "POST"
        event = ConferenceEvent.find(params[:id].to_s)
        event.attributes = whitelisted_event_params
        event.save
        redirect_to(action: "show_event", id: event.id)
      else
        @event = ConferenceEvent.find(params[:id].to_s)
      end
    else
      flash_error(:edit_event_not_allowed.l)
      redirect_to(action: "index")
    end
  end

  def register # :nologin: :norobots:
    store_location
    event = ConferenceEvent.find(params[:id].to_s)
    if request.method == "POST"
      registration = find_previous_registration(params)
      if registration.nil?
        registration = ConferenceRegistration.
                       new(whitelisted_registration_params)
        registration.conference_event = event
        registration.save
        flash_notice(:register_success.l(name: event.name,
                                         how_many: registration.how_many))
        QueuedEmail::Registered.create_email(@user, registration)
      end
      redirect_to(action: "show_event", id: event.id)
    else
      @event = event
    end
  end

  def find_previous_registration(params)
    all_registrations =
      ConferenceRegistration.where(email: "#{params[:registration][:email]}",
                                   conference_event_id: "#{params[:id]}")
    return nil if all_registrations.empty?

    result = all_registrations.first
    before = result.describe
    flash_warning(:register_update_warning.t(description: before))
    result.update_from_params(whitelisted_registration_params)
    result.save
    QueuedEmail::UpdateRegistration.create_email(@user, result, before)
    result
  end

  def list_registrations # :norobots:
    if in_admin_mode?
      @event = ConferenceEvent.find(params[:id].to_s)
      @hello = "Hello"
    else
      flash_error(:list_registrations_not_allowed.l)
      redirect_to(action: "index")
    end
  end

  def verify # :nologin: :norobots:
    registration = ConferenceRegistration.find(params[:id].to_s)
    if registration.verified.nil?
      registration.verified = Time.now
      registration.save
      event = registration.conference_event
      flash_notice(:conference_verify_success.
        l(event: event.name, registrant: registration.name,
          how_many: registration.how_many))
      redirect_to(action: "show_event", id: event.id)
    else
      flash_warning(:conference_verify_warning.l)
      redirect_to(action: :index)
    end
  end
  ################################################################################

  private

  def whitelisted_event_params
    params.require(:event).
      permit(:name, :location, :description, :registration_note,
             "start(1i)", "start(2i)", "start(3i)",
             "end(1i)", "end(2i)", "end(3i)")
  end

  def whitelisted_registration_params
    params.require(:registration).permit(:name, :email, :how_many, :notes)
  end
end
