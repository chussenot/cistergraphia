# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require 'open3'

# The page's five ways (public/js/ways.js) are the library's (Layout): the
# desk of a pathless plate lays them over the grid in the browser, so the
# two must agree at every size, turned signs included
class WaysTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)
  SCRIPT = <<~JS
    const ways = require(process.argv[1]);
    const out = {};
    for (const way of ways.NAMES) out[way] = Array.from({ length: 14 }, (_, i) => ways.path(i + 1, way));
    console.log(JSON.stringify(out));
  JS

  def test_the_pages_ways_are_the_librarys_at_every_side
    skip 'node is not installed' unless system('node', '--version', out: File::NULL, err: File::NULL)
    out, err, status = Open3.capture3('node', '-e', SCRIPT, File.join(ROOT, 'public/js/ways.js'))

    assert_predicate status, :success?, err
    paths = JSON.parse(out)

    assert_equal Cistergraphia::Layout::KEYLESS.map(&:to_s), paths.keys
    paths.each do |way, by_size|
      by_size.each_with_index do |path, i|
        assert_equal Cistergraphia::Layout.path(i + 1, way.to_sym), path, "#{way} at #{i + 1}"
      end
    end
  end
end
