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

  it 'saves the raw message for text-only mail' do
    letter = deliver_letter(location, html: false)

    expect(letter).not_to be_rich
    expect(letter.source).to include('Hello Bob')
  end

  it 'keeps letter_opener from opening a browser, and restores LAUNCHY_DRY_RUN afterwards' do
    original = ENV.fetch('LAUNCHY_DRY_RUN', nil)
    ENV['LAUNCHY_DRY_RUN'] = 'previous'
    allow(Launchy).to receive(:open) { expect(ENV.fetch('LAUNCHY_DRY_RUN', nil)).to eq('true') }

    deliver_letter(location)

    expect(Launchy).to have_received(:open)
    expect(ENV.fetch('LAUNCHY_DRY_RUN', nil)).to eq('previous')
  ensure
    ENV['LAUNCHY_DRY_RUN'] = original
  end

  it 'ignores a missing browser launcher' do
    allow(Launchy).to receive(:open).and_raise(Launchy::CommandNotFoundError)

    expect { deliver_letter(location) }.not_to raise_error
  end
end
