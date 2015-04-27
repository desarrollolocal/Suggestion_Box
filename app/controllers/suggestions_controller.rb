require 'image_manager.rb'

class SuggestionsController < ApplicationController
  before_action :set_suggestion, only: [:show, :edit, :update, :destroy]
  before_action :new_image_manager_filter, only: [:show, :edit]

  def index
    suggestions = search_by(params[:title], params[:address], params[:distance])
    @suggestions = suggestions.paginate(:page => params[:page], :per_page => 10)
  end

  def show
    @comments = Suggestion.friendly.find(params[:id]).comments.where(visible: true)
  end

  def new
    @suggestion = Suggestion.new
  end

  def edit
  end

  def create
    suggestion_builder = SuggestionBuilder.new
    @suggestion = suggestion_builder.create(suggestion_params, params[:image1_id], params[:image2_id])

    render :new and return if @suggestion.errors.any?

    flash[:info] = I18n.t('suggestions.create.flash_create_ok') if @suggestion.visible
    flash[:info] = I18n.t('suggestions.create.flash_email_info') if !@suggestion.visible
    redirect_to @suggestion
  end

  def update
      if @suggestion.update(suggestion_params)
        flash[:info] = t('.flash_update_ok')
        redirect_to @suggestion
      else
        render :edit
      end
  end

  def destroy
    @suggestion.destroy
    flash[:info] = t('.flash_destroy_ok')
    redirect_to suggestions_url
  end

  def validation
    @suggestion = Suggestion.find_by(token_validation: params[:token])
    unless @suggestion.nil?
      @suggestion.update(visible: true)
      # Add email to white list
      if WhiteListEmail.find_by(email: @suggestion.email).nil?
        WhiteListEmail.new(email: @suggestion.email).save
      end
      render 'suggestions/validation'
    else
      render 'suggestions/fail'
    end
  end

  private
    def search_by(title, address, distance)
      conditions = "1 = 1 "
      if !title.nil? && !title.blank?
        words = title.split(" ")
        conditions += "AND ("
        words.each_with_index do |word, index|
          conditions += "(upper(title) LIKE upper('%#{word}%'))"
          conditions += " OR " if index != words.size - 1
        end
        conditions += ")"
      end

      suggestions = Suggestion.where(conditions).order(created_at: :desc)

      if !address.nil? && !address.blank?
        suggestions = suggestions.near(address, distance.to_f, unit: :km).reorder('distance ASC')
      end

      return suggestions
    end

    def set_suggestion
      @suggestion = Suggestion.friendly.find(params[:id])
    end

    def new_image_manager_filter
      @image_manager = ImageManager.new
    end

    def suggestion_params
      params.require(:suggestion).permit(:title, :author, :email, :comment, :latitude, :longitude)
    end
end
