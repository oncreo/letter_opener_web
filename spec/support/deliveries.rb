# frozen_string_literal: true

require 'mail'

module Deliveries
  # Delivers a real email through LetterOpenerWeb::DeliveryMethod, so specs
  # read letters exactly as letter_opener writes them.
  def deliver_letter(location, subject: 'Your weekly report', html: true, text: true, attachment: false)
    mail = Mail.new(from: 'Jane Smith <jane@example.com>', to: 'bob@example.com', cc: 'carol@example.com',
                    subject: subject)
    if html
      mail.html_part = Mail::Part.new(content_type: 'text/html; charset=UTF-8',
                                      body: '<html><body><p style="color:#333">Hello <b>Bob</b></p>' \
                                            '<img src="attachments/logo.png"></body></html>')
    end
    mail.text_part = Mail::Part.new(body: "Hello Bob\nhttps://example.com") if text
    mail.attachments['report.csv'] = "a,b\n1,2\n" if attachment
    deliver(location, mail)
  end

  def deliver(location, mail)
    LetterOpenerWeb::DeliveryMethod.new(location: location).deliver!(mail)
    LetterOpenerWeb::Letter.search.first
  end
end

RSpec.configure { |config| config.include Deliveries }
