# frozen_string_literal: true

ENV['APP_ENV'] = 'test'

require 'bundler/setup'
require 'minitest/autorun'
require_relative '../lib/cistergraphia'
