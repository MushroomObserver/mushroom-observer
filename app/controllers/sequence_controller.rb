#  Controller for nucleotide Sequences
#
#  Actions
#
#    add_sequence::      Create new sequence and add to Observation
#    destroy_sequence::  Destroy sequence
#    edit_sequence::     Update sequence
#    show_sequence::     Display sequence details
#
#
class SequenceController < ApplicationController
  before_action :login_required, except: :show_sequence
  before_action :pass_query_params
  before_action :store_location

  def add_sequence
    @observation = find_or_goto_index(Observation, params[:id].to_s)
    return unless @observation

    if !check_permission(@observation)
      flash_warning(:permission_denied.t)
      redirect_to_show_observation
   else
      build_sequence
    end
  end

  def edit_sequence
  end

  def destroy_sequence
  end

  def show_sequence
  end

##############################################################################

  private

  def build_sequence
    request.method != "POST" ? init_create_sequence : process_create_sequence
  end

  def init_create_sequence
  end

  def process_create_sequence
    @sequence = @observation.sequences.new()
    @sequence.attributes = whitelisted_sequence_params
    @sequence.user = @user
    @sequence.save
    redirect_to_show_observation
  end

  def redirect_to_show_observation
    redirect_with_query(controller: "observer",
                        action: "show_observation", id: @observation.id)
  end

  def whitelisted_sequence_params
    params[:sequence].permit(:archive, :accession, :bases, :locus, :notes)
  end
end
