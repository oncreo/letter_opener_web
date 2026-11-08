# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LetterOpenerWeb::LettersController do
  routes { LetterOpenerWeb::Engine.routes }

  after(:each) { LetterOpenerWeb.reset! }

  describe 'GET index' do
    before do
      allow(LetterOpenerWeb::Letter).to receive(:search).and_return([])
      get :index
    end

    it 'searches for all letters' do
      expect(LetterOpenerWeb::Letter).to have_received(:search)
    end

    it 'returns an HTML 200 response' do
      expect(response.status).to eq(200)
      expect(response.content_type).to eq('text/html; charset=utf-8')
    end
  end

  describe 'GET show' do
    it 'opens the letter in the reader' do
      get :show, params: { id: 'an-id', style: 'rich' }
      expect(response).to redirect_to(letters_path(letter: 'an-id'))
    end
  end

  describe 'GET attachment' do
    let(:id)              { 'an-id' }
    let(:attachment_path) { 'path/to/attachment' }
    let(:file_name)       { 'image.jpg' }
    let(:letter)          { double(:letter, attachments: { file_name => attachment_path }, id: id) }

    before do
      allow(LetterOpenerWeb::Letter).to receive(:find).with(id).and_return(letter)
      allow(letter).to receive(:valid?).and_return(true)
    end

    context 'when the file exists' do
      before do
        # Stub a 200 response b/c `send_file` will 204 when the file doesn't actually exist
        allow(controller).to receive(:send_file) { controller.head :ok }
      end

      it 'sends the file as an inline attachment' do
        get :attachment, params: { id: id, file: file_name }

        expect(response.status).to eq(200)
        expect(controller).to have_received(:send_file)
          .with(attachment_path, filename: file_name, disposition: 'inline')
      end

      context 'when file name includes a dot' do
        let(:file_name) { 'image.dot.jpg' }

        it 'sends the file as an inline attachment' do
          expect(controller).to receive(:send_file).with(attachment_path, filename: file_name,
                                                                          disposition: 'inline')
          get :attachment, params: { id: id, file: file_name }
          expect(response.status).to eq(200)
        end
      end
    end

    it "returns a 404 if attachment file can't be found" do
      get :attachment, params: { id: id, file: 'unknown.woot' }

      expect(response.status).to eq(404)
    end
  end

  describe 'DELETE clear' do
    it 'removes all letters' do
      expect(LetterOpenerWeb::Letter).to receive(:destroy_all)
      delete :clear
    end

    it 'redirects back to index' do
      delete :clear
      expect(response).to redirect_to(letters_path)
    end
  end

  describe 'DELETE destroy' do
    let(:id) { 'an-id' }

    it 'removes the selected letter' do
      allow_any_instance_of(LetterOpenerWeb::Letter).to receive(:valid?).and_return(true)
      expect_any_instance_of(LetterOpenerWeb::Letter).to receive(:delete)
      delete :destroy, params: { id: id }
    end

    it 'throws a 404 if attachment is outside of the letters base path' do
      bad_id = '../an-id'

      allow_any_instance_of(LetterOpenerWeb::Letter).to receive(:valid?).and_return(false)
      expect_any_instance_of(LetterOpenerWeb::Letter).not_to receive(:delete)

      delete :destroy, params: { id: bad_id }

      expect(response.status).to eq(404)
    end
  end
end

RSpec.describe LetterOpenerWeb::LettersController, 'with delivered letters' do
  routes { LetterOpenerWeb::Engine.routes }
  render_views

  let(:location) { Pathname.new(__dir__).join('..', '..', 'tmp', 'controller').cleanpath }

  before { LetterOpenerWeb.configure { |config| config.letters_location = location } }

  let!(:letter) { deliver_letter(location, attachment: true) }

  after do
    LetterOpenerWeb.reset!
    FileUtils.rm_rf(location)
  end

  describe 'GET index' do
    it 'lists letters and shows the newest one' do
      get :index

      expect(response.body).to include('Your weekly report')
      expect(response.body).to include('Jane Smith')
      expect(response.body).to include(letter_body_path(letter, style: 'rich'))
      expect(response.body).to include('report.csv')
      expect(response.body).not_to include('jquery')
    end

    it 'shows the requested letter' do
      other = deliver_letter(location, subject: 'Another one')
      get :index, params: { letter: letter.id }

      expect(response.body).to include(%(data-letter="#{letter.id}"))
      expect(response.body).not_to include(%(data-letter="#{other.id}"))
    end

    it 'shows the empty state without letters' do
      FileUtils.rm_rf(location)
      get :index

      expect(response.body).to include('No letter selected')
    end
  end

  describe 'GET list' do
    it 'renders just the list' do
      get :list

      expect(response.body).to include('Your weekly report')
      expect(response.body).not_to include('<html')
    end
  end

  describe 'GET status' do
    it 'returns the fingerprint' do
      get :status

      expect(response.parsed_body).to eq('fingerprint' => LetterOpenerWeb::Letter.fingerprint)
    end
  end

  describe 'GET details' do
    it 'renders the reader for one letter' do
      get :details, params: { id: letter.id }

      expect(response.body).to include('carol@example.com')
      expect(response.body).to include(letter_source_path(letter, download: 1))
      expect(response.body).not_to include('<html')
    end
  end

  describe 'GET body' do
    it 'renders the HTML body with a base pointing at the letter' do
      get :body, params: { id: letter.id, style: 'rich' }

      expect(response.body).to start_with(%(<base href="#{letter_path(letter)}/" target="_blank">))
      expect(response.body).to include('Hello <b>Bob</b>')
      expect(response.body).not_to include('message_headers')
    end

    it 'renders the plain text body' do
      get :body, params: { id: letter.id, style: 'plain' }

      expect(response.body).to include('<pre>Hello Bob')
    end

    it 'returns 404 for a style the letter does not have' do
      html_only = deliver_letter(location, subject: 'HTML only', text: false)
      get :body, params: { id: html_only.id, style: 'plain' }

      expect(response.status).to eq(404)
    end
  end

  describe 'GET source' do
    it 'shows the raw message' do
      get :source, params: { id: letter.id }

      expect(response.content_type).to start_with('text/plain')
      expect(response.body).to include('Subject: Your weekly report')
    end

    it 'downloads it as an .eml file' do
      get :source, params: { id: letter.id, download: 1 }

      expect(response.headers['Content-Disposition']).to include(%(filename="#{letter.id}.eml"))
    end

    it 'returns 404 for letters delivered without one' do
      File.delete(location.join(letter.id, 'message.eml'))
      get :source, params: { id: letter.id }

      expect(response.status).to eq(404)
    end
  end

  describe 'POST destroy as JSON' do
    it 'deletes the letter' do
      post :destroy, params: { id: letter.id }, format: :json

      expect(response.status).to eq(204)
      expect(LetterOpenerWeb::Letter.search).to be_empty
    end
  end

  describe 'POST clear as JSON' do
    it 'deletes all letters' do
      post :clear, format: :json

      expect(response.status).to eq(204)
      expect(LetterOpenerWeb::Letter.search).to be_empty
    end
  end
end
