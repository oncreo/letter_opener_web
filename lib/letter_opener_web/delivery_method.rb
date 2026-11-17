# frozen_string_literal: true

require 'letter_opener/delivery_method'

module LetterOpenerWeb
  class DeliveryMethod < LetterOpener::DeliveryMethod
    def deliver!(mail)
      original = ENV.fetch('LAUNCHY_DRY_RUN', nil)
      ENV['LAUNCHY_DRY_RUN'] = 'true'

      deliver_with_source(mail) { super }
    rescue Launchy::CommandNotFoundError
      # Ignore for non-executable Launchy environment.
    ensure
      ENV['LAUNCHY_DRY_RUN'] = original
    end

    private

    def deliver_with_source(mail)
      raw = mail.encoded
      yield
    ensure
      save_source(mail, raw) if raw
    end

    # letter_opener only keeps the rendered HTML, so keep the raw message too
    # for the Source view and the .eml download.
    def save_source(mail, raw)
      rendered = (mail['location_rich'] || mail['location_plain'])&.value
      return if rendered.blank?

      File.write(File.join(File.dirname(rendered), LetterOpenerWeb::Letter::SOURCE_FILE), raw)
    end
  end
end
