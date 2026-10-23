# frozen_string_literal: true

require_relative 'test_helper'
require 'open3'
require 'tmpdir'

# The command line (./cistergraphia), run as a reader would: every kind of plate
# written and read back through the file, and the refusals with their exit codes
class CliTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)
  MESSAGE = 'ora et labora'

  def setup
    @dir = Dir.mktmpdir
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  # [stdout, stderr, exit status]; Ruby's own warnings on stderr (an older
  # bundler on a newer rubygems prints some at boot) are the machine's, not the CLI's
  def cli(*, env: {}, stdin: '')
    out, err, status = Open3.capture3(env, File.join(ROOT, 'cistergraphia'), *, chdir: ROOT, stdin_data: stdin)
    [out, err.lines.grep_v(/\A\S+\.rb:\d+: warning: /).join, status.exitstatus]
  end

  # What a Leiden edition allows the message to be: [r] was restored, [b/l] is either
  def allowed(edition)
    parts = edition.strip.split(/\[([^\]]+)\]/) # the brackets' contents at the odd indices
    /\A#{parts.each_with_index.map { |part, i| i.odd? ? "[#{part.delete('/')}]" : Regexp.escape(part) }.join}\z/
  end

  def plate(name)
    File.join(@dir, "#{name}.svg")
  end

  def test_a_plate_is_written_and_read_back
    _, _, status = cli('-m', MESSAGE, '-o', plate('intact'))
    assert_equal 0, status
    assert_includes File.read(plate('intact')), '<svg'
    out, _, status = cli('-d', plate('intact'))
    assert_equal [0, MESSAGE], [status, out.strip]
  end

  def test_a_rongorongo_plate_is_read_back_without_being_told_its_layout
    cli('-m', MESSAGE, '-l', 'rongorongo', '-o', plate('rows'))
    out, _, status = cli('-d', plate('rows'))
    assert_equal [0, MESSAGE], [status, out.strip]
  end

  def test_the_new_ways_are_written_and_read_back_without_being_told
    %w[leap furrows unwinding].each do |way|
      cli('-m', MESSAGE, '-l', way, '-o', plate(way))
      out, _, status = cli('-d', plate(way))
      assert_equal [0, MESSAGE], [status, out.strip], way
    end
  end

  def test_a_pathless_plate_is_announced_read_back_and_refused_where_it_cannot_be
    out, _, status = cli('-m', MESSAGE, '-l', 'unwinding', '--pathless', '-o', plate('pathless'))
    assert_equal [0, true], [status, out.start_with?('Pathless: the plate says nothing of where it begins')]
    assert_includes File.read(plate('pathless')), 'class="pathless"'
    out, _, status = cli('-d', plate('pathless'))
    assert_equal [0, MESSAGE], [status, out.strip]
    _, err, status = cli('-m', MESSAGE, '--pathless', '-b', '-o', plate('no'))
    assert_equal [1, Cistergraphia::Pathless::NOT_BROKEN], [status, err.strip]
    _, err, status = cli('-m', MESSAGE, '--pathless', '-s', '-o', plate('no'),
                         env: { 'CISTERGRAPHIA_PASSPHRASE' => 'abbey of molesme' })
    assert_equal [1, Cistergraphia::Pathless::NOT_SEALED], [status, err.strip]
  end

  def test_a_plate_with_its_own_tablet_shows_the_scribe_the_tablet_and_reads_back_by_its_seed
    out, _, status = cli('-m', MESSAGE, '-l', 'leap', '--own-tablet', '-o', plate('own'))
    seed = out[/Its own tablet \(seed ([A-Z0-9-]{11})\)/, 1]
    assert_equal [0, 27], [status, out.scan(/(?:^|\s)[a-z␣] \d{4}(?=\s|\z)/).size], 'the seed, the twenty-seven rows'
    assert_equal Cistergraphia::Tablet.normalize(seed), Cistergraphia::Tablet.seed_of(File.read(plate('own')))
    out, _, status = cli('-d', plate('own'))
    assert_equal [0, MESSAGE], [status, out.strip]
    _, err, status = cli('-m', MESSAGE, '--own-tablet', '-w', '-o', plate('no'))
    assert_equal [1, Cistergraphia::Tablet::NOT_DAMAGED], [status, err.strip]
  end

  def test_the_expert_plate_is_pathless_with_its_own_tablet_and_reads_back
    out, _, status = cli('-m', MESSAGE, '-l', 'furrows', '--pathless', '--own-tablet', '-o', plate('expert'))
    assert_equal 0, status
    assert_includes out, 'Pathless: the plate says nothing of where it begins'
    assert_includes out, 'Its own tablet (seed '
    out, _, status = cli('-d', plate('expert'))
    assert_equal [0, MESSAGE], [status, out.strip]
  end

  def test_a_worn_pathless_plate_is_announced_twice_and_reads_back_as_an_edition
    out, _, status = cli('-m', MESSAGE, '-l', 'furrows', '-w', '--pathless', '-o', plate('worn-pathless'))
    assert_equal 0, status
    assert_match(/\AWeathered: \d+ lacunae?\. .*\n/, out)
    assert_includes out, 'Pathless: the plate says nothing of where it begins; the bench finds the way'
    svg = File.read(plate('worn-pathless'))
    assert_includes svg, 'class="pathless"'
    assert_includes svg, 'class="lacunae"'
    edition, _, status = cli('-d', plate('worn-pathless'))
    assert_equal 0, status
    assert_match allowed(edition), MESSAGE, 'the message, within what the edition allows'
  end

  def test_a_worn_plate_says_its_lacunae_and_reads_back_as_an_edition
    out, _, status = cli('-m', MESSAGE, '-w', '-o', plate('worn'))
    assert_equal 0, status
    assert_match(/\AWeathered: \d+ lacunae\. Restore them/, out)
    edition, _, status = cli('-d', plate('worn'))
    assert_equal 0, status
    assert_match(%r{\[[a-z /]+\]}, edition, 'restorations in brackets')
    assert_match allowed(edition), MESSAGE, 'the message, within what the edition allows'
  end

  def test_a_broken_plate_says_its_fragments_and_is_read_back_rejoined
    out, _, status = cli('-m', MESSAGE, '-b', '-o', plate('broken'))
    assert_equal 0, status
    assert_match(/\ABroken: \d+ fragments\. Rejoin them/, out)
    message, _, status = cli('-d', plate('broken'))
    assert_equal [0, MESSAGE], [status, message.strip]
  end

  def test_a_tallied_worn_plate_reads_back
    cli('-m', MESSAGE, '-t', '-w', '-o', plate('tallied'))
    edition, _, status = cli('-d', plate('tallied'))
    assert_equal 0, status
    assert_match allowed(edition), MESSAGE
  end

  def test_a_grille_plate_gives_its_key_and_needs_it_to_read
    out, _, status = cli('-m', MESSAGE, '-l', 'grille', '-o', plate('grille'), '--stencil', plate('stencil'))
    assert_equal 0, status
    key = out[/Grille key: (\S+)/, 1]
    assert_match(/\A[A-Z0-9]{5}-[A-Z0-9]{5}\z/, key)
    assert_includes File.read(plate('stencil')), 'stencil-sheet'
    message, _, status = cli('-d', plate('grille'), '-g', key)
    assert_equal [0, MESSAGE], [status, message.strip]
  end

  def test_a_grille_plate_without_its_key_is_refused_with_the_way_in
    cli('-m', MESSAGE, '-l', 'grille', '-o', plate('grille'))
    _, err, status = cli('-d', plate('grille'))
    assert_equal 1, status
    assert_includes err, 'written under a grille: it needs its key. Add --grille KEY'
  end

  def test_two_readers_the_abbot_reads_both_messages_and_the_novice_the_decoy
    out, _, status = cli('-m', MESSAGE, '--decoy', 'vespers at six', '-o', plate('two'))
    assert_equal 0, status
    abbot = out[/Abbot's key: (\S+)/, 1]
    novice = out[/Novice's key: (\S+)/, 1]
    both, = cli('-d', plate('two'), '-g', abbot)
    assert_includes both, MESSAGE
    assert_includes both, 'vespers at six'
    only, = cli('-d', plate('two'), '-g', novice)
    assert_includes only, 'vespers at six'
    refute_includes only, MESSAGE
  end

  def test_a_sealed_plate_opens_with_its_passphrase_and_refuses_another
    env = { 'CISTERGRAPHIA_PASSPHRASE' => 'abbey of molesme' }
    _, _, status = cli('-m', MESSAGE, '-s', '-o', plate('sealed'), env: env)
    assert_equal 0, status
    message, _, status = cli('-d', plate('sealed'), '-s', env: env)
    assert_equal [0, MESSAGE], [status, message.strip]
    _, err, status = cli('-d', plate('sealed'), '-s', env: { 'CISTERGRAPHIA_PASSPHRASE' => 'wrong passphrase' })
    assert_equal 1, status
    assert_includes err, 'Wrong passphrase'
  end

  def test_a_file_that_is_not_a_plate_is_refused_cleanly
    File.write(plate('not'), 'hello')
    out, err, status = cli('-d', plate('not'))
    assert_equal 1, status
    assert_includes err, 'Unreadable SVG'
    assert_empty out
    refute_match(/\.rb:\d+/, err, 'no backtrace')
  end

  def test_a_missing_message_is_refused
    _, err, status = cli(stdin: '')
    assert_equal 1, status
    assert_includes err, 'Message has no characters that can be enciphered'
  end

  def test_help_lists_every_option
    out, _, status = cli('--help')
    assert_equal 0, status
    %w[--message --output --png --decode --layout --grille --stencil --decoy --weathered --broken --tally --secret]
      .each { |option| assert_includes out, option }
  end
end
