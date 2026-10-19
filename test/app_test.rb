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

  def test_key_illustrations_are_the_real_glyph_geometry_pressed
    get '/'

    Cistergraphia::Glyphs.strokes(1098).each do |stroke|
      assert_includes last_response.body, %(<path d="#{Cistergraphia::Stylus.press(stroke)}"/>)
    end
  end

  def test_game_mode_ignores_a_stray_passphrase
    post '/generate', message: 'Agent 007', mode: 'game', passphrase: 'abbey of molesme'

    assert_includes last_response.body, 'Enciphered as: <code>agent</code>'
  end

  def test_secret_mode_requires_a_passphrase
    post '/generate', message: 'hello', mode: 'secret', passphrase: ''

    assert_equal 422, last_response.status # back to the form, not an error page
    assert_match(%r{id="passphrase-error"[^>]*>Secret mode needs a passphrase</p>}m, last_response.body)
  end

  def test_domain_errors_never_show_the_backtrace_page
    # Development shows Sinatra's backtrace page for 500s unless handlers run first
    assert_equal :after_handler, CistergraphiaApp.settings.show_exceptions
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
    strokes = [Cistergraphia::Glyphs::STEM, *Cistergraphia::Glyphs::LINES.values.flatten(1)]
    assert_equal(strokes.to_h { |stroke| [stroke.join(','), Cistergraphia::Stylus.press(stroke)] }, table['wedges'])
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

  def plate_of(body)
    cells = JSON.parse(CGI.unescapeHTML(body[/data-plate-cells="([^"]*)"/, 1]))
    layout = JSON.parse(CGI.unescapeHTML(body[/data-plate-layout="([^"]*)"/, 1]))
    svg = CGI.unescapeHTML(body[/<input type="hidden" name="svg" value="([^"]*)"/, 1])
    [cells, layout, svg]
  end

  def test_plate_can_be_walked_in_reading_order
    post '/generate', message: 'Ora et labora'
    cells, layout, svg = plate_of(last_response.body)

    assert_equal(Cistergraphia::SVG.read(svg), cells.map { |_, _, value, _| value }) # values, in reading order
    assert_equal(Cistergraphia.spiral_coordinates(layout['size']), cells.map { |row, col, _| [row, col] })
    assert(cells.none? { |*, turned| turned })
    assert_equal({ 'padding' => 50, 'cell' => [120, 170], 'offset' => -10, 'grille' => false }, layout.except('size'))
    assert_includes last_response.body, 'tabindex="0"'
  end

  def test_inscribe_puts_the_choices_first_and_reserves_its_dynamic_parts
    get '/'
    body = last_response.body
    order = ['name="mode"', 'name="layout"', 'id="message"', 'data-preview', 'id="passphrase"', 'data-submit']

    assert_equal(order, order.sort_by { |marker| body.index(marker) }) # choices above what you type
    refute_match(/<div class="preview[^"]*" data-preview[^>]* hidden[ >]/, body) # laid out from the first paint
    assert_includes body, 'preview-note--secret'                       # the sealed state shares the strip
    assert_includes body, 'class="slot secret-slot"'                   # unfolded by CSS, not by JS
    assert_includes body, 'class="slot grille-slot"'
    assert_match(/anatomy-hint awaits-script/, body)                   # space kept until JS
  end

  def test_index_offers_three_layouts
    get '/'

    assert_match(/name="layout" value="phaistos" checked/, last_response.body)
    assert_match(/name="layout" value="rongorongo"/, last_response.body)
    assert_match(/name="layout" value="grille"/, last_response.body)
    assert_equal 3, last_response.body.scan('data-layout-note=').size # the key follows the choice
  end

  def test_rongorongo_plate_is_walked_with_its_turned_rows
    post '/generate', message: 'Ora et labora', layout: 'rongorongo'
    cells, layout, svg = plate_of(last_response.body)

    assert_includes last_response.body, '<dd>Rongorongo</dd>'
    assert_includes last_response.body, 'data-action="turn-plate"'
    assert_equal(Cistergraphia::SVG.read(svg, layout: :rongorongo), cells.map { |_, _, value, _| value })
    assert_equal(Cistergraphia.boustrophedon_coordinates(layout['size']),
                 cells.map { |row, col, _, turned| [row, col, turned] })

    post '/decode', svg: svg

    assert_includes last_response.body, 'ora et labora'
  end

  def test_plate_keeps_its_caption_and_controls_in_place
    post '/generate', message: 'abbey', layout: 'rongorongo'
    body = last_response.body

    assert_match(/plate-reading-rest/, body) # the resting caption keeps its place...
    assert_match(%r{data-plate-reading aria-live="polite"></span>}, body) # ...while the live reading fills it
    assert_match(/plate-hint awaits-script/, body)
    assert_match(/btn awaits-script" data-action="turn-plate"/, body)
    refute_match(/<(?:span|button)[^>]* hidden[ >]/, body)
  end

  def test_unknown_layouts_fall_back_to_the_snail
    post '/generate', message: 'abbey', layout: '<script>'

    assert_predicate last_response, :ok?
    assert_includes last_response.body, '<dd>Phaistos</dd>'
    refute_includes last_response.body, 'turn-plate'
  end

  def test_anatomy_corners_are_dials_enabled_by_script
    get '/'

    dial = /<button type="button" class="quadrant quadrant--(\w+)" data-place="(\d+)" disabled>/
    dials = last_response.body.scan(dial)
    assert_equal [%w[tens 10], %w[units 1], %w[thousands 1000], %w[hundreds 100]], dials
  end

  def test_grille_plate_shows_its_key_and_its_stencil
    post '/generate', message: 'Ora et labora', layout: 'grille', grille: 'k7q2m zxb4p'
    body = last_response.body

    assert_includes body, '<dd>Grille</dd>'
    assert_includes body, '<code class="grille-key">K7Q2M-ZXB4P</code>'
    assert_includes body, 'data-action="lay-grille"'
    assert_includes body, '<template data-stencil="whole"'
    assert_includes body, '<input type="hidden" name="grille" value="K7Q2M-ZXB4P">' # read it back with its grille
  end

  def test_grille_plate_is_walked_through_the_grille
    post '/generate', message: 'Ora et labora', layout: 'grille', grille: 'k7q2m zxb4p'
    cells, layout, svg = plate_of(last_response.body)
    grille = Cistergraphia::Grille.new('K7Q2M-ZXB4P')

    assert_equal(grille.path(layout['size']), cells.map { |row, col, _| [row, col] })
    assert_equal({ 'padding' => 50, 'cell' => [170, 170], 'offset' => 0, 'grille' => true }, layout.except('size'))
    assert_equal 'ora et labora', Cistergraphia.decode(svg, layout: grille)
  end

  def test_a_grille_is_drawn_for_each_plate_unless_its_key_is_given
    keys = Array.new(2) do
      post '/generate', message: 'Ora et labora', layout: 'grille'
      last_response.body[%r{<code class="grille-key">([^<]+)</code>}, 1]
    end

    assert(keys.all? { |key| key.match?(/\A\w{5}-\w{5}\z/) })
    refute_equal keys.first, keys.last
  end

  def test_a_malformed_grille_key_returns_to_the_form_with_what_was_written
    post '/generate', message: 'Ora et labora', layout: 'grille', grille: 'abbey'

    assert_equal 422, last_response.status
    body = last_response.body
    assert_match(/id="grille-error"[^>]*>A grille key has 10 letters and digits/, body)
    assert_match(/name="layout" value="grille" checked/, body)
    refute_match(/name="layout" value="phaistos" checked/, body)
    assert_includes body, 'value="abbey"'
    assert_includes body, 'Ora et labora'
  end

  def test_a_grille_plate_is_read_with_its_key_and_asks_for_it_without
    _, svg = Cistergraphia.inscribe('Vespers at six', layout: Cistergraphia::Grille.new('K7Q2M-ZXB4P'))

    post '/decode', svg: svg
    assert_equal 400, last_response.status
    assert_includes last_response.body, 'This plate was written under a grille: it needs its key.'

    post '/decode', svg: svg, grille: 'k7q2m-zxb4p'
    assert_predicate last_response, :ok?
    assert_includes last_response.body, 'vespers at six'

    post '/decode', svg: svg, grille: '00000-00000'
    assert_includes last_response.body, Cistergraphia::Grille::WRONG_KEY
    refute_includes last_response.body, 'secret mode' # the key is the problem here, not a passphrase
  end

  def test_a_plate_for_two_readers_shows_both_keys_and_both_stencils
    post '/generate', message: 'Relics lie under the third pillar', decoy: 'Vespers at six', layout: 'grille',
                      grille: 'K7Q2M-ZXB4P'
    body = last_response.body
    novice = Cistergraphia::Grille.new('K7Q2M-ZXB4P').novice

    assert_includes body, '<dd>Grille, two readers</dd>'
    assert_includes body, '<code class="grille-key">K7Q2M-ZXB4P</code>'
    assert_includes body, %(<code class="grille-key">#{novice}</code>)
    assert_includes body, '<template data-stencil="abbot"'
    assert_includes body, '<template data-stencil="novice"'
    assert_match(/class="decoy-echo".*Vespers at six/m, body)
    assert_includes body, '<input type="hidden" name="grille" value="K7Q2M-ZXB4P">' # the abbot reads it back
  end

  def test_the_abbot_reads_both_messages_and_the_novice_one
    _, svg, abbot = Cistergraphia::TwoReaders.inscribe('Relics lie here', 'Vespers at six', grille: Cistergraphia::Grille.new('K7Q2M-ZXB4P'))

    post '/decode', svg: svg, grille: abbot.to_s
    assert_includes last_response.body, 'relics lie here'
    assert_match(/The novice’s grille reads.*vespers at six/m, last_response.body)

    post '/decode', svg: svg, grille: abbot.novice.to_s
    assert_includes last_response.body, 'vespers at six'
    refute_includes last_response.body, 'relics'
  end

  def test_too_long_a_pair_returns_to_the_form
    post '/generate', message: 'x' * 300, decoy: 'Vespers', layout: 'grille'

    assert_equal 422, last_response.status
    assert_match(/id="decoy-error"[^>]*>With two readers, each message is limited to 250 characters/,
                 last_response.body)
  end

  def test_largest_sealed_pair_fits_the_upload_limit
    message = '🙏' * CistergraphiaApp::MAX_PAIR_LENGTH
    _, svg, = Cistergraphia::TwoReaders.inscribe(message, message, passphrase: 'abbey of molesme')

    assert_operator svg.bytesize, :<, CistergraphiaApp::MAX_SVG_BYTES
  end

  def test_largest_sealed_grille_plate_fits_the_upload_limit
    message = '🙏' * CistergraphiaApp::MAX_MESSAGE_LENGTH
    layout = Cistergraphia::Grille.new('K7Q2M-ZXB4P')
    svg = Cistergraphia.to_svg(Cistergraphia.encode(message, passphrase: 'abbey of molesme', even: true),
                               layout: layout)

    assert_operator svg.bytesize, :<, CistergraphiaApp::MAX_SVG_BYTES
  end

  def test_about_page_explains_the_three_layouts_and_their_origins
    get '/about'

    body = last_response.body
    assert_includes body, 'Three ways to read a plate'
    assert_includes body, 'reverse boustrophedon'
    %w[Phaistos_Disc Rongorongo Cardan_grille].each { |page| assert_includes body, "https://en.wikipedia.org/wiki/#{page}" }
    assert_equal 3, body.scan('<svg class="turning"').size # the disc, the tablet, Cardano's letter
    assert_equal 2, body.scan('<svg class="snail"').size   # and each layout drawn from it
    assert_equal 1, body.scan('<svg class="grille-order"').size
    assert_includes body, 'id="layouts"'                   # linked from the inscribe key
    refute_match(/why a snail|began with|the default/i, body) # neither layout comes first
  end

  def test_about_page_offers_lectio
    get '/about'

    body = last_response.body
    assert_match(/<section class="lectio" data-lectio aria-labelledby/, body) # laid out from the start
    assert_match(/data-lectio-sign data-number="[1-9]"><svg class="glyph"/, body)
    assert_match(/data-lectio-answer disabled>/, body) # enabled by JS
    assert_match(/data-lectio-submit disabled>/, body)
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

  def test_short_passphrase_comes_back_to_the_form_with_what_was_written
    post '/generate', message: 'Rendez-vous at dawn', mode: 'secret', passphrase: 'short', layout: 'rongorongo'
    body = last_response.body

    assert_equal 422, last_response.status
    assert_match(%r{id="passphrase-error"[^>]*>A passphrase needs at least 8 characters</p>}m, body)
    assert_match(/aria-invalid="true" autofocus/, body)
    assert_includes body, '>Rendez-vous at dawn</textarea>'
    assert_match(/value="secret" checked/, body)
    assert_match(/value="rongorongo" checked/, body)
    assert_includes body, '<body data-mode="secret">'
    refute_includes body, 'value="short"' # the passphrase is never sent back
  end

  def test_decode_with_a_short_passphrase_is_a_wrong_passphrase
    svg = Cistergraphia.to_svg(Cistergraphia.encode('hidden', passphrase: 'right passphrase'))
    post '/decode', svg: svg, passphrase: 'short'

    assert_equal 400, last_response.status
    assert_includes last_response.body, 'Wrong passphrase'
  end

  def test_decode_secret_image_with_wrong_passphrase
    svg = Cistergraphia.to_svg(Cistergraphia.encode('hidden', passphrase: 'right passphrase'))
    post '/decode', svg: svg, passphrase: 'wrong passphrase'

    assert_equal 400, last_response.status
    assert_includes last_response.body, 'Wrong passphrase'
  end

  def test_secret_rongorongo_round_trip_through_the_web
    post '/generate', message: 'Hanga Roa', passphrase: 'orongo village', layout: 'rongorongo'
    svg = last_response.body[%r{<svg xmlns.*?</svg>}m]

    post '/decode', svg: svg, passphrase: 'orongo village'

    assert_includes last_response.body, 'Hanga Roa'
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

  def test_the_form_offers_a_weathered_plate
    get '/'

    assert_match(/<input type="checkbox" name="weathered" value="1"/, last_response.body)
    assert_includes last_response.body, 'A sealed plate cannot weather'
  end

  def test_a_weathered_plate_shows_its_lacunae_and_never_its_lost_values
    post '/generate', message: 'the brothers will gather in the chapter house', weathered: '1'

    assert_predicate last_response, :ok?
    body = last_response.body
    assert_includes body, 'class="weathering"'
    assert_match(%r{<dt>Condition</dt><dd>Weathered</dd>}, body)
    assert_match(/Weathered: \d+ lacunae/, body)
    cells = JSON.parse(CGI.unescapeHTML(body[/data-plate-cells="([^"]*)"/, 1]))
    assert(cells.any? { |_, _, value| value.nil? }, 'a worn sign has no value on the page')
    refute_match(/ style="/, body)
  end

  def test_a_weathered_plate_has_a_bench_that_never_holds_a_lost_value
    post '/generate', message: 'the brothers will gather in the chapter house', weathered: '1'

    body = last_response.body
    lacunae = JSON.parse(CGI.unescapeHTML(body[/data-lacunae="([^"]*)"/, 1]))
    refute_empty lacunae
    lacunae.each { |lacuna| assert_lacuna_shows_only_the_file(lacuna) }
    assert_match(/data-bench-sum>[\d?]{4} \+ [\d?]{4} = \?</, body)
    assert_match(/data-bench-edition>[^<]*\[\.\]/, body)
    assert_equal 10, body.scan('class="bench-digit"').size
  end

  # A lacuna's options differ only in its own place: what the visible strokes allow, nothing more
  def assert_lacuna_shows_only_the_file(lacuna)
    place = lacuna['place']
    assert_includes [1, 10, 100, 1000], place
    refute_empty lacuna['options']
    assert(lacuna['options'].map { |v| v - ((v / place) % 10 * place) }.uniq.one?)
  end

  def test_an_intact_plate_has_no_bench
    post '/generate', message: 'ora et labora'

    refute_includes last_response.body, 'data-bench'
  end

  def test_a_sealed_plate_cannot_weather
    post '/generate', message: 'relics', mode: 'secret', passphrase: 'abbey of molesme', weathered: '1'

    assert_equal 422, last_response.status
    assert_includes last_response.body, Cistergraphia::Lacunae::NOT_SEALED
    assert_match(/name="weathered" value="1" data-weathered checked/, last_response.body)
  end

  def test_two_readers_cannot_weather_yet
    post '/generate', message: 'relics', layout: 'grille', decoy: 'vespers', weathered: '1'

    assert_equal 422, last_response.status
    assert_includes last_response.body, Cistergraphia::Lacunae::NOT_TWO_READERS
  end

  def test_a_weathered_plate_is_read_back_as_an_edition
    _, svg, = Cistergraphia::Lacunae.inscribe('ora et labora', random: Random.new(3))

    post '/decode', svg: svg
    assert_predicate last_response, :ok?
    assert_includes last_response.body, 'Restored from a weathered plate'
    assert_match(%r{<span class="leiden-(restored|doubt)">\[[^<]*\]</span>}, last_response.body)
  end

  def test_a_weathered_grille_plate_is_read_with_its_key
    grille = Cistergraphia::Grille.new('K7Q2M-ZXB4P')
    _, svg, = Cistergraphia::Lacunae.inscribe('ora et labora', layout: grille)

    post '/decode', svg: svg, grille: grille.to_s
    assert_predicate last_response, :ok?
    assert_includes last_response.body, 'leiden-'
  end
end
