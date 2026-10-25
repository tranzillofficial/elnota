-- Release bucket only; provider/project quotas still apply.
update storage.buckets set file_size_limit = null where id = 'elnota-app-releases';
