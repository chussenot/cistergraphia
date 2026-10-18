# frozen_string_literal: true

# Renders the social preview images from web/og/card.html.erb with headless
# Chromium, through Playwright when available (exact viewport), otherwise the
# Chromium command line (run: bundle exec rake og:image):
#   public/og.png             1200x630, Open Graph / Twitter card
#   docs/social-preview.png   1280x640, GitHub repository social preview
#
# The plate uses a fixed seed, so the images are reproducible.

require 'erb'
require 'fileutils'
require 'tmpdir'
require_relative '../../lib/cistergraphia'

ROOT = File.expand_path('../..', __dir__)
OUTPUTS = {
  File.join(ROOT, 'public/og.png') => [1200, 630],
  File.join(ROOT, 'docs/social-preview.png') => [1280, 640]
}.freeze

def chromium
  candidates = [ENV.fetch('CHROME', nil), 'chromium', 'chromium-browser', 'google-chrome',
                *Dir.glob('/opt/pw-browsers/chromium-*/chrome-linux/chrome')].compact
  candidates.find { |c| File.executable?(c) || system('which', c, out: File::NULL, err: File::NULL) } ||
    abort('Chromium not found: set CHROME=/path/to/chrome')
end

def card_html(width, height)
  srand(1098)
  sequence = Cistergraphia.encode('ora et labora')
  mark = Cistergraphia::Glyphs.strokes(1098).map do |x1, y1, x2, y2|
    %(<line x1="#{x1}" y1="#{y1}" x2="#{x2}" y2="#{y2}"/>)
  end.join
  ERB.new(File.read(File.join(__dir__, 'card.html.erb'))).result_with_hash(
    width: width, height: height, fonts: "file://#{ROOT}/public/fonts",
    mark: mark, plate: Cistergraphia.to_svg(sequence)
  )
end

def playwright?
  system('node', '-e', "require('playwright')", out: File::NULL, err: File::NULL)
end

def screenshot(html, output, width, height)
  if playwright?
    system('node', File.join(__dir__, 'screenshot.js'), html, output, width.to_s, height.to_s, chromium)
  else
    system(chromium, '--headless=new', '--no-sandbox', '--disable-gpu', '--hide-scrollbars',
           '--force-device-scale-factor=1', "--window-size=#{width},#{height}",
           "--screenshot=#{output}", "file://#{html}", out: File::NULL, err: File::NULL)
  end
end

Dir.mktmpdir do |dir|
  OUTPUTS.each do |output, (width, height)|
    html = File.join(dir, "card-#{width}.html")
    File.write(html, card_html(width, height))
    screenshot(html, output, width, height) || abort("Chromium failed to render #{output}")
    system('pngquant', '--quality=75-95', '--force', '--ext', '.png', output) if system('which pngquant > /dev/null')
    puts "#{output} (#{width}x#{height}, #{File.size(output) / 1024} KB)"
  end
end
