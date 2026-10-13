# frozen_string_literal: true

# Cistergraphia Rack Configuration
# ================================
#
# Purpose:
# - Application entry point for any Rack server (`bundle exec rackup`)

require 'bundler/setup'
require_relative 'app'

run CistergraphiaApp
