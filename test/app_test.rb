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

  def test_decode_rejects_oversized_svg
    post '/decode', svg: ' ' * (CistergraphiaApp::MAX_SVG_BYTES + 1)

    assert_equal 413, last_response.status
  end
end
