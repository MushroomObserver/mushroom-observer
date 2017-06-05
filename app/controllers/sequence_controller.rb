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
    return unless (@obs = find_or_goto_index(Observation, params[:id].to_s))

    if !check_permission(@obs)
      redirect_with_query(controller: "observer",
                          action: "show_observation", id: @obs.id)
    else
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

  def create_sequence
    request.method != "POST" ? init_create_sequence : process_create_sequence
  end

  def init_create_sequence
    @sequence = @obs.sequences.new()
  end

  def process_create_sequence
    @sequence.attributes = whitelisted_sequence_params
    @sequence.save
  end

  def whitelisted_sequence_params
    params[:sequence].permit(:archive, :accession, :bases, :locus, :notes)
  end
end
