# frozen_string_literal: true

require 'test_helper'
require 'rack/test'
require_relative '../app'

class AppTest < Minitest::Test
  include Rack::Test::Methods

  def app
    CistergraphiaApp
  end

  def test_index_renders_the_form
    get '/'

    assert_predicate last_response, :ok?
    assert_includes last_response.body, '<form method="post" action="/generate">'
  end

  def test_generate_renders_an_inline_svg
    post '/generate', message: 'hello world'

    assert_predicate last_response, :ok?
    assert_includes last_response.body, '<svg xmlns="http://www.w3.org/2000/svg"'
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
end
