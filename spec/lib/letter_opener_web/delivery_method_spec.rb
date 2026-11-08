# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LetterOpenerWeb::DeliveryMethod do
  let(:location) { Pathname.new(__dir__).join('..', '..', 'tmp', 'deliveries').cleanpath }

  before { LetterOpenerWeb.configure { |config| config.letters_location = location } }

  after do
    LetterOpenerWeb.reset!
    FileUtils.rm_rf(location)
  end

  it 'saves the rendered letter and the raw message' do
    letter = deliver_letter(location)

    expect(letter).to be_rich
    expect(letter).to be_plain
    expect(letter.source).to include('Subject: Your weekly report')
    expect(letter.source).not_to include('location_rich')
  end
end
