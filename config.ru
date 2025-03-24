# Cistergraphia Rack Configuration
# ==============================
#
# Purpose:
# - Application entry point
# - Rack middleware configuration
# - Environment setup
#
# Design Decisions:
# - Minimal middleware stack
# - CORS support for API access
# - Bundler for dependency management
#
# Constraints:
# - Must work with various Rack servers
# - Handles both development and production
# - Maintains security headers

require 'rubygems'
require 'bundler'

Bundler.require

require './app'
run CistergraphiaApp 