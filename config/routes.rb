# frozen_string_literal: true

LetterOpenerWeb::Engine.routes.draw do
  get  '/',                     to: 'letters#index',      as: :letters
  get  'list',                  to: 'letters#list',       as: :letters_list
  get  'status',                to: 'letters#status',     as: :letters_status
  post 'clear',                 to: 'letters#clear',      as: :clear_letters
  get  ':id/details',           to: 'letters#details',    as: :letter_details
  get  ':id/body/:style',       to: 'letters#body',       as: :letter_body, constraints: { style: /rich|plain/ }
  get  ':id/source',            to: 'letters#source',     as: :letter_source
  get  ':id(/:style)',          to: 'letters#show',       as: :letter
  post ':id/delete',            to: 'letters#destroy',    as: :delete_letter
  get  ':id/attachments/:file', to: 'letters#attachment', constraints: { file: %r{[^/]+} }
end
