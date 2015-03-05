#!/usr/bin/env ruby
# encoding: UTF-8

FEATURES = %w(
  childsupport
  dailypayment
  homemaker
  noexperience
  nooverwork
  restonweekend
  shortterm
  student
)

def build_bit(feature)
  1 << FEATURES.index(feature)
end

lib_path = File.expand_path '../lib', __FILE__
$LOAD_PATH.unshift lib_path unless $LOAD_PATH.include? lib_path

$ACTIVE_DEBUG = false

require 'helper'
require 'databases'

Database = StagingDatabase

define_tables Database

def update_feature_bits(features)
  @updated_cnt = @updated_cnt ? @updated_cnt : 0

  JobPosting.connection_pool.with_connection do
    features.each do|feature|
      begin
        bit = build_bit feature.title
        JobPosting.where(id: feature.job_posting_id).update_all("feature_bit = feature_bit | #{bit}")
        Logging.log "#{@updated_cnt += 1} JobPostings updated"
      rescue StandardError => err
        Logging.log err.inspect
      end
    end
  end
end

def main
  threads = []

  batch_cnt = 0

  find_in_batches(Feature) do |features|
    batch_cnt += 1
    time("check available database connection batch_#{batch_cnt}") { try_checkout_conn_from JobPosting }
    threads << Thread.new do
      time("update #{features.size} JobPostings batch_#{batch_cnt}") { update_feature_bits features }
    end
  end

  Logging.log "generated #{threads.size} threads"

  threads.each do|t|
    begin
      t.join
    rescue StandardError => err
      Logging.log err.inspect
    end
  end
end

time('main call') { main } if __FILE__ == $PROGRAM_NAME
