# frozen_string_literal: true

class FieldSlipNotesBuilder
  def initialize(params, field_slip)
    @params = params
    @field_slip = field_slip
  end

  def assemble
    notes = {}
    notes[:Collector] = collector
    notes[:Field_Slip_ID] = field_slip_id
    notes[:Field_Slip_ID_By] = field_slip_id_by
    notes[:Other_Codes] = other_codes
    update_notes_fields(notes)
    notes
  end

  private

  def collector
    user_str(@params[:field_slip][:collector])
  end

  def field_slip_id
    str = @params[:field_slip][:field_slip_name]
    return str if str.empty? || str.starts_with?("_")

    "_#{str}_"
  end

  def field_slip_id_by
    user_str(@params[:field_slip][:field_slip_id_by])
  end

  def other_codes
    codes = @params[:field_slip][:other_codes]
    return codes unless @params[:field_slip][:inat] == "1"

    "\"iNat ##{codes}\":https://www.inaturalist.org/observations/#{codes}"
  end

  def update_notes_fields(notes)
    new_notes = @params[:field_slip][:notes]
    return unless new_notes

    @field_slip.notes_fields.each do |field|
      notes[field.name] = new_notes[field.name]
    end
  end

  def user_str(str)
    updated_str = @field_slip.project&.check_for_alias(str, User) || str
    user = User.lookup_unique_text_name(updated_str)
    return user.textile_name if user

    str
  end
end
