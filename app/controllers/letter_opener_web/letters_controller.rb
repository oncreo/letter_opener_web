# frozen_string_literal: true

module LetterOpenerWeb
  class LettersController < ApplicationController
    helper LetterOpenerWeb::LettersHelper

    before_action :load_letter, only: %i[details body source attachment destroy]

    def index
      @letters = LetterOpenerWeb::Letter.search
      @letter = selected_letter
    end

    def list
      @letters = LetterOpenerWeb::Letter.search
      render partial: 'list', locals: { letters: @letters, selected: nil }
    end

    def status
      render json: { fingerprint: LetterOpenerWeb::Letter.fingerprint }
    end

    def details
      render partial: 'reader', locals: { letter: @letter }
    end

    # Old letter URLs open the letter in the reader.
    def show
      redirect_to routes.letters_path(letter: params[:id])
    end

    # Just the email itself, without letter_opener's header block, for the
    # reader iframe. Relative URLs (attachments/...) resolve against the letter.
    def body
      skip_profiler_badge
      content = params[:style] == 'rich' ? @letter.body_html : @letter.body_text_html
      return head :not_found if content.nil?

      if params[:style] == 'rich'
        render html: "#{body_base}#{content}".html_safe
      else
        render partial: 'plain_body', locals: { base: body_base, text: content }
      end
    end

    def source
      return head :not_found unless @letter.source?

      if params[:download]
        send_data @letter.source, filename: "#{@letter.id}.eml", type: 'message/rfc822', disposition: 'attachment'
      else
        render plain: @letter.source
      end
    end

    def attachment
      filename = params[:file]
      file     = @letter.attachments[filename]

      return render plain: 'Attachment not found!', status: 404 unless file.present?

      send_file(file, filename: filename, disposition: 'inline')
    end

    def clear
      LetterOpenerWeb::Letter.destroy_all
      respond_to do |format|
        format.html { redirect_to routes.letters_path }
        format.json { head :no_content }
      end
    end

    def destroy
      @letter.delete
      respond_to do |format|
        format.html { redirect_to routes.letters_path }
        format.json { head :no_content }
      end
    end

    private

    def load_letter
      @letter = LetterOpenerWeb::Letter.find(params[:id])

      head :not_found unless @letter.valid?
    end

    # Keep rack-mini-profiler's badge out of the email itself.
    def skip_profiler_badge
      Rack::MiniProfiler.current&.inject_js = false if defined?(Rack::MiniProfiler)
    end

    def body_base
      view_context.tag.base(href: "#{routes.letter_path(id: @letter.id)}/", target: '_blank')
    end

    def selected_letter
      requested = LetterOpenerWeb::Letter.find(params[:letter]) if params[:letter].present?
      requested&.valid? ? requested : @letters.first
    end

    def routes
      LetterOpenerWeb.railtie_routes_url_helpers
    end
  end
end
