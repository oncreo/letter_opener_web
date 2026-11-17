# frozen_string_literal: true

RSpec.describe LetterOpenerWeb::Letter do
  let(:location) { Pathname.new(__dir__).join('..', '..', 'tmp').cleanpath }

  def rich_text(mail_id)
    <<~MAIL
      Rich text for #{mail_id}
      <!DOCTYPE html>
      <body>
        <div id="container">
          <div id="message_headers">
            <dl>
              <dt>From:</dt>
              <dd>noreply@example.com</dd>
            </dl>
          </div>

          <a href='a-link.html'>
            <img src='an-image.jpg'>
            Link text
          </a>
          <a href='fooo.html'>Bar</a>
          <a href="example.html" class="blank"></a>
          <address><a href="inside-address.html">inside address</a></address>
        </div>
      </body>
    MAIL
  end

  before :each do
    LetterOpenerWeb.configure { |config| config.letters_location = location }

    %w[1111_1111 2222_2222].each do |folder|
      FileUtils.mkdir_p("#{location}/#{folder}")
      File.write("#{location}/#{folder}/plain.html", "Plain text for #{folder}")
      File.write("#{location}/#{folder}/rich.html", rich_text(folder))
      FileUtils.mkdir_p("#{Rails.root.join('tmp', 'letter_opener')}/#{folder}")
      File.write("#{Rails.root.join('tmp', 'letter_opener')}/#{folder}/rich.html", "Rich text for #{folder}")
    end
  end

  after :each do
    LetterOpenerWeb.reset!
    FileUtils.rm_rf(location)
  end

  describe 'attachments' do
    let(:file)            { 'an-image.csv' }
    let(:attachments_dir) { "#{location}/#{id}/attachments" }
    let(:id)              { '1111_1111' }

    subject { described_class.new(id: id) }

    before do
      FileUtils.mkdir_p(attachments_dir)
      File.open("#{attachments_dir}/#{file}", 'w') { |f| f.puts 'csv,contents' }
    end

    it 'builds a hash with file name as key and full path as value' do
      expect(subject.attachments).to eq(file => "#{attachments_dir}/#{file}")
    end
  end

  describe '.search' do
    let(:search_results) { described_class.search }
    let(:first_letter)   { search_results.first }
    let(:last_letter)    { search_results.last }

    before do
      allow(File).to receive(:mtime).with("#{location}/1111_1111").and_return(Date.today - 1.day)
      allow(File).to receive(:mtime).with("#{location}/2222_2222").and_return(Date.today)
    end

    it 'returns a list of ordered letters' do
      expect(first_letter.sent_at).to be > last_letter.sent_at
    end
  end

  describe '.find' do
    let(:id)     { 'an-id' }
    let(:letter) { described_class.find(id) }

    it 'returns a letter with id set' do
      expect(letter.id).to eq(id)
    end
  end

  describe '.destroy_all' do
    it 'removes all letters' do
      described_class.destroy_all
      expect(Dir["#{location}/**/*"]).to be_empty
    end
  end

  describe '#delete' do
    let(:id) { '1111_1111' }

    subject { described_class.new(id: id).delete }

    it 'removes the letter with given id' do
      subject
      directories = Dir["#{location}/*"]
      expect(directories.count).to eql(1)
      expect(directories.first).not_to match(id)
    end

    context 'when the id is outside of the letters base path' do
      let(:id) { '../3333_3333' }

      it 'does not remove the letter' do
        expect(FileUtils).not_to receive(:rm_rf).with(location.join(id).cleanpath.to_s)

        expect(subject).to be_nil
      end
    end
  end
end

RSpec.describe LetterOpenerWeb::Letter, 'reading a delivered letter' do
  let(:location) { Pathname.new(__dir__).join('..', '..', 'tmp', 'delivered').cleanpath }

  before { LetterOpenerWeb.configure { |config| config.letters_location = location } }

  after do
    LetterOpenerWeb.reset!
    FileUtils.rm_rf(location)
  end

  subject(:letter) { deliver_letter(location, attachment: true) }

  it 'reads the header fields letter_opener rendered' do
    expect(letter.subject).to eq('Your weekly report')
    expect(letter.from).to eq('Jane Smith <jane@example.com>')
    expect(letter.to).to eq('bob@example.com')
    expect(letter.header('cc')).to eq('carol@example.com')
    expect(letter.header_fields.map(&:first)).not_to include('Attachments')
  end

  it 'uses the display name as the sender name, or the address without one' do
    expect(letter.sender_name).to eq('Jane Smith')
    allow(letter).to receive(:from).and_return('jane@example.com')
    expect(letter.sender_name).to eq('jane@example.com')
    allow(letter).to receive(:from).and_return('"Smith, Jane" <jane@example.com>')
    expect(letter.sender_name).to eq('Smith, Jane')
  end

  it "extracts the email's own HTML without letter_opener's wrapper" do
    expect(letter.body_html).to start_with('<html><body><p style="color:#333">Hello <b>Bob</b>')
    expect(letter.body_html).not_to include('message_headers')
  end

  it 'extracts the auto-linked plain text' do
    expect(letter.body_text_html).to include('Hello Bob')
    expect(letter.body_text_html).to include('<a href="https://example.com">')
  end

  it 'builds a one-line preview from the text part' do
    expect(letter.preview).to eq('Hello Bob https://example.com')
  end

  it 'falls back to the HTML for the preview when there is no text part' do
    html_only = deliver_letter(location, subject: 'HTML only', text: false)
    expect(html_only.preview).to eq('Hello Bob')
  end

  it 'knows about attachments' do
    expect(letter).to be_attachment
    expect(letter.attachments.keys).to eq(['report.csv'])
  end

  it 'has a source and a sent time' do
    expect(letter).to be_source
    expect(letter.sent_at).to be_within(5).of(Time.now)
  end

  it 'reads the sender address' do
    expect(letter.sender_email).to eq('jane@example.com')
  end

  it 'copes with a From header it cannot parse' do
    allow(letter).to receive(:from).and_return('not an <address')

    expect(letter.sender_name).to eq('not an <address')
    expect(letter.sender_email).to be_nil
  end

  it 'truncates long previews' do
    long = deliver(location, Mail.new(from: 'a@example.com', to: 'b@example.com', subject: 'Long', body: 'word ' * 100))

    expect(long.preview.length).to eq(LetterOpenerWeb::Letter::PREVIEW_LENGTH)
    expect(long.preview).to end_with('...')
  end

  it 'leaves styles and scripts out of an HTML preview' do
    mail = Mail.new(from: 'a@example.com', to: 'b@example.com', subject: 'Styled')
    mail.html_part = Mail::Part.new(content_type: 'text/html; charset=UTF-8',
                                    body: '<html><head><style>p { color: red }</style></head>' \
                                          '<body><script>alert(1)</script><p>Visible</p></body></html>')

    expect(deliver(location, mail).preview).to eq('Visible')
  end

  it 'has no plain body for an HTML-only letter, and no HTML body for a text-only one' do
    html_only = deliver_letter(location, subject: 'HTML only', text: false)
    text_only = deliver_letter(location, subject: 'Text only', html: false)

    expect(html_only).to be_rich
    expect(html_only).not_to be_plain
    expect(html_only.body_text_html).to be_nil
    expect(text_only).not_to be_rich
    expect(text_only.body_html).to be_nil
    expect(text_only.subject).to eq('Text only')
  end

  it 'has no attachments unless some were sent' do
    plain_letter = deliver_letter(location, subject: 'No files')

    expect(plain_letter).not_to be_attachment
    expect(plain_letter.attachments).to eq({})
  end

  describe '#valid?' do
    it 'is true for a delivered letter' do
      expect(letter).to be_valid
    end

    it 'is false for a letter that does not exist' do
      missing = described_class.find('missing')

      expect(missing).not_to be_valid
      expect(missing.sent_at).to be_nil
    end

    it 'is false for the letters folder itself' do
      letter
      expect(described_class.find('.')).not_to be_valid
    end

    it 'is false for a folder next to the letters folder that shares its name as a prefix' do
      sibling = Pathname.new("#{location}_backup")
      FileUtils.mkdir_p(sibling.join('secret'))

      expect(described_class.find("../#{sibling.basename}/secret")).not_to be_valid
    ensure
      FileUtils.rm_rf(sibling)
    end
  end

  describe '.fingerprint' do
    it 'changes when a letter arrives or is deleted' do
      before = described_class.fingerprint
      letter
      after_delivery = described_class.fingerprint
      letter.delete

      expect(after_delivery).not_to eq(before)
      expect(described_class.fingerprint).to eq(before)
    end
  end
end
