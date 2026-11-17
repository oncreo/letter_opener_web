# frozen_string_literal: true

module LetterOpenerWeb
  # Icons, avatars and times for the letters UI.
  module LettersHelper
    # Paths from Lucide (https://lucide.dev, ISC licence).
    ICONS = {
      refresh: '<path d="M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8"/><path d="M21 3v5h-5"/>' \
               '<path d="M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16"/><path d="M8 16H3v5"/>',
      trash: '<path d="M3 6h18"/><path d="M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6"/>' \
             '<path d="M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2"/>',
      sun: '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41' \
           'M2 12h2M20 12h2M6.34 17.66l-1.41 1.41M19.07 4.93l-1.41 1.41"/>',
      moon: '<path d="M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z"/>',
      system: '<circle cx="12" cy="12" r="10"/><path d="M12 18a6 6 0 0 0 0-12v12z"/>',
      desktop: '<rect width="20" height="14" x="2" y="3" rx="2"/><path d="M8 21h8M12 17v4"/>',
      mobile: '<rect width="14" height="20" x="5" y="2" rx="2"/><path d="M12 18h.01"/>',
      paperclip: '<path d="m21.44 11.05-9.19 9.19a6 6 0 0 1-8.49-8.49l8.57-8.57A4 4 0 1 1 18 8.84l-8.59 8.57' \
                 'a2 2 0 0 1-2.83-2.83l8.49-8.48"/>',
      external: '<path d="M15 3h6v6"/><path d="M10 14 21 3"/>' \
                '<path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/>',
      search: '<circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/>',
      download: '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><path d="m7 10 5 5 5-5"/><path d="M12 15V3"/>',
      mail: '<rect width="20" height="16" x="2" y="4" rx="2"/><path d="m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7"/>',
      back: '<path d="m15 18-6-6 6-6"/>',
      inbox: '<path d="M22 12h-6l-2 3h-4l-2-3H2"/><path d="M5.45 5.11 2 12v6a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-6' \
             'l-3.45-6.89A2 2 0 0 0 16.76 4H7.24a2 2 0 0 0-1.79 1.11z"/>'
    }.freeze

    def lo_icon(name, size: 16)
      tag.svg(ICONS.fetch(name).html_safe,
              class: 'icon', width: size, height: size, viewBox: '0 0 24 24', fill: 'none',
              stroke: 'currentColor', 'stroke-width': 2, 'stroke-linecap': 'round', 'stroke-linejoin': 'round',
              'aria-hidden': true)
    end

    def lo_avatar(letter)
      name = letter.sender_name.to_s
      tag.span(name.first.to_s.upcase.presence || '?', class: "avatar hue-#{name.bytes.sum % 12}", 'aria-hidden': true)
    end

    def lo_time(time, format: '%-d %b %Y, %H:%M:%S')
      return if time.nil?

      tag.time(time.strftime(format), datetime: time.iso8601, title: time.strftime(format))
    end

    def lo_nonce
      content_security_policy_nonce if respond_to?(:content_security_policy_nonce)
    end
  end
end
