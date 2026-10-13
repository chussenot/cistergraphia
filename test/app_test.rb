# frozen_string_literal: true

require 'test_helper'
require 'rack/test'
require_relative '../app'

class AppTest < Minitest::Test
  include Rack::Test::Methods

  def app
    CistergraphiaApp
  end

  def test_index_renders_the_form_and_links_to_decode
    get '/'

    assert_predicate last_response, :ok?
    assert_includes last_response.body, '<form method="post" action="/generate">'
    assert_includes last_response.body, 'href="/decode"'
  end

  def test_generate_renders_an_inline_svg
    post '/generate', message: 'hello world'

    assert_predicate last_response, :ok?
    assert_includes last_response.body, '<svg xmlns="http://www.w3.org/2000/svg"'
  end

  def test_generate_shows_how_the_message_was_normalized
    post '/generate', message: 'Agent 007'

    assert_includes last_response.body, 'Enciphered as: <code>agent</code>'
  end

  def test_generate_escapes_the_reflected_message
    post '/generate', message: 'hi <script>alert(document.domain)</script>'

    assert_predicate last_response, :ok?
    refute_includes last_response.body, '<script>alert(document.domain)</script>'
    assert_includes last_response.body, '&lt;script&gt;'
  end

  def test_generate_accepts_digits_and_underscores
    post '/generate', message: 'r2d2_and_c3po'

    assert_predicate last_response, :ok?
  end

  def test_generate_rejects_messages_without_cipherable_characters
    post '/generate', message: '!!!'

    assert_equal 400, last_response.status
    assert_includes last_response.body, 'no characters that can be enciphered'
  end

  def test_generate_rejects_missing_message
    post '/generate'

    assert_equal 400, last_response.status
  end

  def test_generate_rejects_oversized_messages
    post '/generate', message: 'a' * (CistergraphiaApp::MAX_MESSAGE_LENGTH + 1)

    assert_equal 413, last_response.status
  end

  def test_decode_form_renders
    get '/decode'

    assert_predicate last_response, :ok?
    assert_includes last_response.body, 'enctype="multipart/form-data"'
  end

  def test_decode_pasted_svg
    post '/decode', svg: Cistergraphia.to_svg(Cistergraphia.encode('Meet me at dawn!'))

    assert_predicate last_response, :ok?
    assert_includes last_response.body, 'meet me at dawn'
  end

  def test_decode_uploaded_svg
    file = Rack::Test::UploadedFile.new(StringIO.new(Cistergraphia.to_svg(Cistergraphia.encode('scriptorium'))),
                                        'image/svg+xml', original_filename: 'cipher.svg')
    post '/decode', file: file

    assert_predicate last_response, :ok?
    assert_includes last_response.body, 'scriptorium'
  end

  def test_decode_falls_back_to_pasted_svg_when_the_upload_is_empty
    empty = Rack::Test::UploadedFile.new(StringIO.new(''), 'image/svg+xml', original_filename: 'empty.svg')
    post '/decode', file: empty, svg: Cistergraphia.to_svg(Cistergraphia.encode('abbey'))

    assert_predicate last_response, :ok?
    assert_includes last_response.body, 'abbey'
  end

  def test_decode_rejects_foreign_svg
    post '/decode', svg: '<svg xmlns="http://www.w3.org/2000/svg"><circle r="4"/></svg>'

    assert_equal 400, last_response.status
    assert_includes last_response.body, 'No Cistergraphia symbols found'
  end

  def test_secret_mode_round_trip_through_the_web
    post '/generate', message: 'Cîteaux, 1098!', passphrase: 'abbey of molesme'

    assert_predicate last_response, :ok?
    assert_includes last_response.body, 'Secret mode'
    svg = last_response.body[%r{<svg xmlns.*?</svg>}m]

    post '/decode', svg: svg, passphrase: 'abbey of molesme'

    assert_predicate last_response, :ok?
    assert_includes last_response.body, 'Cîteaux, 1098!'
  end

  def test_blank_passphrase_means_game_mode
    post '/generate', message: 'Agent 007', passphrase: ''

    assert_includes last_response.body, 'Enciphered as: <code>agent</code>'
  end

  def test_secret_mode_rejects_short_passphrase
    post '/generate', message: 'hello', passphrase: 'short'

    assert_equal 400, last_response.status
    assert_includes last_response.body, 'at least 8 characters'
  end

  def test_decode_secret_image_with_wrong_passphrase
    svg = Cistergraphia.to_svg(Cistergraphia.encode('hidden', passphrase: 'right passphrase'))
    post '/decode', svg: svg, passphrase: 'wrong passphrase'

    assert_equal 400, last_response.status
    assert_includes last_response.body, 'Wrong passphrase'
  end

  def test_decode_secret_image_without_passphrase_hints_at_secret_mode
    post '/decode', svg: Cistergraphia.to_svg(Cistergraphia.encode('hidden', passphrase: 'right passphrase'))

    assert_equal 400, last_response.status
    assert_includes last_response.body, 'enter its passphrase'
  end

  def test_largest_secret_message_fits_the_upload_limit
    message = '🙏' * CistergraphiaApp::MAX_MESSAGE_LENGTH
    svg = Cistergraphia.to_svg(Cistergraphia.encode(message, passphrase: 'abbey of molesme'))

    assert_operator svg.bytesize, :<, CistergraphiaApp::MAX_SVG_BYTES
  end

  def test_decode_rejects_oversized_svg
    post '/decode', svg: ' ' * (CistergraphiaApp::MAX_SVG_BYTES + 1)

    assert_equal 413, last_response.status
  end
end
