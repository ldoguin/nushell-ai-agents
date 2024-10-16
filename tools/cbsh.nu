# Run a vector search for a given repo, ideally the repo has been previously cloned and indexed with import_git_repo
export def ask_repo [repoName, question] {
    cb-env bucket "cbsh"
    cb-env scope "gitlog"
    cb-env collection $repoName
    let result = ( vector enrich-text  $question | vector search $repoName textVector --neighbors 10| select id |doc get| select content | reject -i content.textVector | par-each {|x| to json} | wrap content| ask $question )
    print $result
    $result
}

# Clone a repo, extract it's commit history, upsert it and enrich it with it's embedding, create the vector index if it does not exist
export def import_git_repo [repoPath : string, repoName : string ] {
    if ( ( ls | where name == "scratchpad" ) == []) {
        mkdir scratchpad
    }
    cd ./scratchpad
    if ( ( ls | where name == "couchbase-shell" ) == []) {
        git clone $repoPath
        cd $repoName
    } else {
        cd $repoName
        git pull
    }
    # with bash, extract your commit history to json
    bash -c "source  ../../tools/git-log-json.sh; git-log-json > commitlog.json"
    # with cbsh, create scope, collection and collection Primary Index
    dbSetup "cbsh" "gitlog" $repoName
    # Import the doc in selected collection
    open commitlog.json |  wrap content | insert id { |it|  echo $it.content.commitHash } | doc upsert
    # Enrich the document with default model 
    query $"SELECT c.*, meta\(\).id as id, c.subject || '  '  || c.body as text FROM `($repoName)` as c"  | reject cluster | wrap content| insert id { |row| $row.content.id } | insert content.textVector { |row|  (  $row.content.text | vector enrich-text | $in.content.vector ) } | doc upsert
    # Create a Vector Index
    let indexName = $"(cb-env | $in.bucket).( cb-env | $in.scope ).($repoName)"
    if ( ( query indexes | where  type == "fts" and nname == indexName ) == [] ) {
        vector create-index --similarity-metric dot_product $repoName textVector 1536
    }
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