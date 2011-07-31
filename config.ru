$: << "lib" << "lib/pace"

require 'rubygems'
require 'resque'
require 'resque/server'
require 'pace'
require 'pace/server'

run Resque::Server