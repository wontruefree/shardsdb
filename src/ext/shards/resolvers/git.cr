class Shards::GitResolver
  private def mirror_repository
    run_in_current_folder "git clone --mirror --quiet -- #{Helpers::Path.escape(git_url)} #{local_path}"
  rescue error : Error
    raise Error.new("Failed to clone #{git_url}: #{error.message}")
  end

  private def fetch_repository
    run "git fetch --all --quiet"
  rescue error : Error
    raise Error.new("Failed to update #{git_url}: #{error.message}")
  end

  # def commit_hash(version : String? = nil)
  #   capture("git log -n 1 --pretty=%H #{git_refs(version)}").strip
  # end
  # def commit_date(version : String? = nil)
  #   #Time.parse_iso8601 capture("git log -n 1 --pretty=%cI #{git_refs(version)}").strip
  #   repo = Git::Repo.open(local_path)
  #   tag = repo.tags[version]
  #   commit = repo.lookup_commit(tag.target_oid)
  #   commit.time
  # end
  # # def revision_info(version)
  # #   repo = Git::Repo.open(local_path)
  # #   p! repo, version, repo.tags
  # #   begin
  # #     tag = repo.tags["v#{version}"]
  # #   rescue Git::Error
  # #     # try without v prefix
  # #     tag = repo.tags[version]
  # #   end
  # #   p! tag.target_oid
  # #   commit = repo.lookup_commit(tag.target_oid)

  # #   Release::RevisionInfo.new Release::Tag.new(tag.name, tag.message, signature(tag.tagger)),
  # #                             Release::Commit.new(commit.sha, commit.time, signature(commit.author), signature(commit.committer), commit.message)
  # # end

  # # private def signature(signature)
  # #   Release::Signature.new(signature.name, signature.email, signature.time)
  # # end

  def revision_info(version)
    tag = Release::Tag.from_json(tag_json(version)) rescue nil
    commit = Release::Commit.from_json(commit_json(version))

    Release::RevisionInfo.new tag, commit
  end

  private def commit_json(version)
    format = <<-FORMAT.gsub("%n", '\n')
        {
          "sha": "%H",
          "time": "%cI",
          "author": {
            "name": "%aN",
            "email": "%aE",
            "time": "%aI"
          },
          "committer": {
            "name": "%cN",
            "email": "%cE",
            "time": "%cI"
          },
          "message": "%s"
        }
      FORMAT

    refs = git_refs(version)

    capture("git log -n 1 --pretty=format:'#{format}' #{refs}")
  end

  private def tag_json(version)
    format = <<-FORMAT
        {
          "name": "v#{version}",
          "message": "%(contents)",
          "tagger": {
            "name": "%(tagger)",
            "email": "%(taggeremail)",
            "time": "%(taggerdate:I)",
          }
        }
      FORMAT

    capture("git for-each-ref refs/tags/v#{version} --shell --format='#{format}'")
  end

  private def git_refs(version)
    case version
    when RELEASE_VERSION
      if version && version.starts_with?('v')
        version
      else
        vversion = "v#{version}"
        begin
          if version_at(vversion)
            return vversion
          end
        rescue Error
        end

        version
      end
    when "*"
      "HEAD"
    else
      version || "HEAD"
    end
  end
end
