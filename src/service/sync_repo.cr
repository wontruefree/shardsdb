require "taskmaster"
require "../db"
require "../ext/yaml/any"
require "../repo/resolver"
require "./sync_release"
require "./order_releases"

# This service synchronizes the information about a repository in the database.
struct Service::SyncRepo
  include Taskmaster::Job

  def initialize(@shard_id : Int32)
  end

  def perform
    ShardsDB.transaction do |db|
      repo = db.find_canonical_repo(@shard_id)
      resolver = Repo::Resolver.new(repo.ref)

      sync_repo(db, resolver)
    end
  end

  def sync_repo(db, resolver : Repo::Resolver)
    versions = resolver.fetch_versions

    versions.each do |version|
      if !SoftwareVersion.valid?(version)
        # TODO: What should happen when a version tag is invalid?
        # Ignoring for now.
        next
      end

      SyncRelease.new(@shard_id, version).sync_release(db, resolver)
    end

    yank_releases_with_missing_versions(db, versions)

    Service::OrderReleases.new(@shard_id).order_releases(db)

    update_repo_synced_at(db)
  end

  def yank_releases_with_missing_versions(db, versions)
    db.connection.exec <<-SQL, @shard_id, versions
      UPDATE
        releases
      SET
        yanked_at = NOW()
      WHERE
        shard_id = $1 AND yanked_at IS NULL AND version <> ALL($2)
      SQL
  end

  def update_repo_synced_at(db)
    db.connection.exec <<-SQL, @shard_id
      UPDATE
        repos
      SET
        synced_at = NOW()
      WHERE
        shard_id = $1 AND role = 'canonical'
      SQL
  end
end
