require 'minitest/autorun'

$LOAD_PATH.unshift "./lib"
require "houston"

def fixture(filename)
  File.read("#{File.dirname(__FILE__)}/fixtures/#{filename}")
end
