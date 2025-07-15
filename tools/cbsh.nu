# Run a vector search for a given repo, ideally the repo has been previously cloned and indexed with import_git_repo
export def ask_repo [repoName, question] {
    let repoName = if ( $repoName |str index-of / | $in > 0) {
        ($repoName | str substring ($repoName | str index-of / | $in + 1).. )
    } else {
        $repoName
    }
    cb-env bucket "cbsh"
    cb-env scope "gitlog"
    cb-env collection $repoName
    let result = ( vector enrich-text  $question | vector search $repoName textVector --neighbors 10| select id |doc get| select content | reject -i content.textVector | par-each {|x| to json} | wrap content| ask $question )
    print $result
    $result
}

# Clone a repo, extract it's commit history, upsert it and enrich it with it's embedding, create the vector index if it does not exist
export def import_git_repo [repoPath : string, repoFullName : string ] {
    if ( ( ls | where name == "scratchpad" ) == []) {
        mkdir scratchpad
    }
    cd ./scratchpad
    let repoName = ($repoFullName | str substring ($repoFullName | str index-of / | $in + 1).. )
    if ( ( ls | where name == $repoName ) == []) {
        git clone $repoPath
        cd $repoName
    } else {
        cd $repoName
        git pull
    }
    # extract your commit history to json
    git_log
    # with cbsh, create scope, collection and collection Primary Index
    dbSetup "cbsh" "gitlog" $repoName
    # Import the doc in selected collection
    open commitlog.json |  wrap content | insert id { |it|  echo $it.content.commit_hash } | doc insert
    # Enrich the document with default model 
    let docsToUpdate = query $"SELECT c.*, meta\(\).id as id, c.message || '  '  || c.body as text FROM `($repoName)` as c WHERE IFMISSINGORNULL\(textVector, \"\"\) = \"\" "
    if (  $docsToUpdate != null ) {
        $docsToUpdate | wrap content| insert id { |row| $row.content.id } | insert content.textVector { |row|  (  $row.content.text | vector enrich-text | $in.content.vector ) } | doc upsert
        # Create a Vector Index
        let indexName = $"(cb-env | $in.bucket).( cb-env | $in.scope ).($repoName)"
        if ( ( query indexes | where  type == "fts" and name == $indexName ) == [] ) {
            vector create-index --similarity-metric dot_product $repoName textVector 1536
        }
    }
}

export def git_log [] {
   let logs = git log --all --pretty=format:'%n{%n"branch": "%d",%n  "commit_hash": "%H",%n  "author": "%an",%n  "author_email": "%ae",%n  "date": "%ad",%n  "commiter_name": "%cN",%n  "commiter_email": "%cE",%n  "message": "%f",%n "body": "%b"%n}' | lines | find --regex "^origin" --invert | str replace "}" "}," | append "]" | prepend "[" | drop nth 3 | to text | from json
   $logs | save -f commitlog.json
}

# Create the given bucket, scope, collection and primary index if they don't exist.
export def dbSetup [bucket: string; scope: string; collection: string] {
    cb-env | print
    if (buckets| where name == $bucket | is-empty) {buckets create --replicas 1 $bucket 100; print $"Create Bucket ($bucket)"} else {print "Bucket already exist"}
    cb-env bucket $bucket
    if (scopes| where scope == $scope | is-empty) {scopes create $scope; print $"Create Scope ($scope)"} else {print "Scope already exist"}
    cb-env scope $scope
    if (collections| where collection == $collection | is-empty) {collections create $collection; print $"Create Collection ($collection)"} else {print "Collection already exist"}
    cb-env collection $collection
    query $"CREATE PRIMARY INDEX IF NOT EXISTS ON `default`:`($bucket)`.`($scope)`.`($collection)`"
    cb-env
}