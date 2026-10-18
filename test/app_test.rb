# frozen_string_literal: true

require 'test_helper'
require 'cgi'
require 'json'
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
    assert_match(%r{<form [^>]*method="post" action="/generate"}, last_response.body)
    assert_includes last_response.body, 'href="/decode"'
  end

  def test_pages_send_a_strict_content_security_policy
    get '/'

    csp = last_response.headers['Content-Security-Policy']
    assert_includes csp, "default-src 'self'"
    assert_includes csp, "frame-ancestors 'none'"
    assert_equal 'no-referrer', last_response.headers['Referrer-Policy']
    refute_match(/<script>|<style>| style="| on[a-z]+="/, last_response.body) # nothing inline for the CSP to block
  end

  def test_results_carrying_messages_are_never_cached
    post '/generate', message: 'hello', mode: 'secret', passphrase: 'abbey of molesme'

    assert_includes last_response.headers['Cache-Control'], 'no-store'
  end

  def test_static_assets_are_served
    %w[/css/app.css /js/app.js /favicon.svg /fonts/eb-garamond-latin-400-normal.woff2].each do |path|
      get path

      assert_predicate last_response, :ok?, path
    end
  end

  def test_key_illustrations_use_the_real_glyph_geometry
    get '/'

    Cistergraphia::Glyphs.strokes(1098).each do |x1, y1, x2, y2|
      assert_includes last_response.body, %(<line x1="#{x1}" y1="#{y1}" x2="#{x2}" y2="#{y2}"/>)
    end
  end

  def test_game_mode_ignores_a_stray_passphrase
    post '/generate', message: 'Agent 007', mode: 'game', passphrase: 'abbey of molesme'

    assert_includes last_response.body, 'Enciphered as: <code>agent</code>'
  end

  def test_secret_mode_requires_a_passphrase
    post '/generate', message: 'hello', mode: 'secret', passphrase: ''

    assert_equal 400, last_response.status
    assert_includes last_response.body, 'Secret mode needs a passphrase'
  end

  def test_result_page_can_read_its_plate_back
    post '/generate', message: 'Ora et labora'
    svg = CGI.unescapeHTML(last_response.body[/<input type="hidden" name="svg" value="([^"]*)"/, 1])

    post '/decode', svg: svg

    assert_includes last_response.body, 'ora et labora'
  end

  def test_live_preview_embeds_the_library_glyph_table
    get '/'

    json = CGI.unescapeHTML(last_response.body[/data-glyph-table="([^"]*)"/, 1])
    table = JSON.parse(json)
    assert_equal Cistergraphia::Glyphs::STEM, table['stem']
    assert_equal(Cistergraphia::Glyphs::LINES.transform_keys(&:to_s), table['lines'])
    assert_equal 9000, table['tablet'][' ']
    assert_equal 10, table['tablet']['a']
  end

  def test_about_page
    get '/about'

    assert_predicate last_response, :ok?
    body = last_response.body
    assert_includes body, '<title>About the ciphers · Cistergraphia</title>'
    assert_includes body, 'href="/about" class="is-current" aria-current="page"'
    assert_includes body, 'data-playground'
    tablet = body[%r{<ol class="tablet">(.*?)</ol>}m, 1]
    assert_equal Cistergraphia::TABLET.size, tablet.scan('<li>').size
    assert_includes body, 'John of Basingstoke'
  end

  def test_pages_carry_social_preview_metadata
    get '/about'

    assert_includes last_response.body, '<meta property="og:image" content="http://example.org/og.png">'
    assert_includes last_response.body, '<meta property="og:title" content="About the ciphers">'
    assert_includes last_response.body, '<meta name="twitter:card" content="summary_large_image">'

    get '/og.png'

    assert_predicate last_response, :ok?
    assert_equal 'image/png', last_response.content_type
  end

  def test_plate_can_be_walked_in_reading_order
    post '/generate', message: 'Ora et labora'
    body = last_response.body
    cells = JSON.parse(CGI.unescapeHTML(body[/data-plate-cells="([^"]*)"/, 1]))
    layout = JSON.parse(CGI.unescapeHTML(body[/data-plate-layout="([^"]*)"/, 1]))
    svg = CGI.unescapeHTML(body[/<input type="hidden" name="svg" value="([^"]*)"/, 1])

    assert_equal Cistergraphia::SVG.read(svg), cells.map(&:last) # values, in reading order
    assert_equal(Cistergraphia.spiral_coordinates(layout['size']), cells.map { |row, col, _| [row, col] })
    assert_equal({ 'padding' => 50, 'cell' => [120, 170], 'space' => 20 }, layout.except('size'))
    assert_includes body, 'tabindex="0"'
  end

  def test_anatomy_corners_are_dials_enabled_by_script
    get '/'

    dial = /<button type="button" class="quadrant quadrant--(\w+)" data-place="(\d+)" disabled>/
    dials = last_response.body.scan(dial)
    assert_equal [%w[tens 10], %w[units 1], %w[thousands 1000], %w[hundreds 100]], dials
  end

  def test_about_page_offers_lectio
    get '/about'

    assert_match(/<section class="lectio" data-lectio hidden/, last_response.body) # revealed by JS only
    assert_includes last_response.body, 'data-lectio-answer'
  end

  def test_unknown_pages_render_the_erratum
    get '/nowhere'

    assert_equal 404, last_response.status
    assert_includes last_response.body, 'not in the index'
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
