require "taskmaster"
require "../db"
require "./sync_repo"

# This service synchronizes the information about a repository in the database.
struct Service::SyncRepos
  include Taskmaster::Job

  def initialize(@older_than : Time)
  end

  def self.new(age : Time::Span = 24.hours)
    new(age.ago)
  end

  def perform
    ShardsDB.transaction do |db|
      sync_repos(db)
    end
  end

  def sync_repos(db)
    shards = db.connection.query_all <<-SQL, @older_than, as: Int32
      SELECT
        shards.id
      FROM
        shards
      JOIN
        repos ON repos.shard_id = shards.id AND repos.role = 'canonical'
      WHERE
        synced_at IS NULL OR synced_at < $1
      SQL

    shards.each do |id|
      Service::SyncRepo.new(id).perform_later
    end
  end
end
