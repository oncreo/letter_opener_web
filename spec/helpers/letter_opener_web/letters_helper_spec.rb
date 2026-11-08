# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LetterOpenerWeb::LettersHelper do
  describe '#lo_icon' do
    it 'renders an inline SVG icon hidden from screen readers' do
      icon = helper.lo_icon(:trash, size: 14)

      expect(icon).to start_with('<svg')
      expect(icon).to include('width="14"', 'height="14"', 'aria-hidden="true"', '<path d="M3 6h18"/>')
    end

    it 'raises for an unknown icon' do
      expect { helper.lo_icon(:nope) }.to raise_error(KeyError)
    end
  end

  describe '#lo_avatar' do
    def letter(sender_name)
      instance_double(LetterOpenerWeb::Letter, sender_name: sender_name)
    end

    it 'shows the upper-cased first letter of the sender' do
      expect(helper.lo_avatar(letter('jane'))).to include('>J</span>')
    end

    it 'gives the same sender the same colour' do
      hue = helper.lo_avatar(letter('Jane'))[/hue-\d+/]

      expect(hue).to be_present
      expect(helper.lo_avatar(letter('Jane'))).to include(hue)
    end

    it 'falls back to a question mark without a sender' do
      expect(helper.lo_avatar(letter(nil))).to include('>?</span>')
    end
  end

  describe '#lo_time' do
    it 'renders a machine-readable time element' do
      time = Time.utc(2026, 3, 4, 5, 6, 7)

      expect(helper.lo_time(time)).to eq(
        '<time datetime="2026-03-04T05:06:07Z" title="4 Mar 2026, 05:06:07">4 Mar 2026, 05:06:07</time>'
      )
    end

    it 'renders nothing without a time' do
      expect(helper.lo_time(nil)).to be_nil
    end
  end
end
