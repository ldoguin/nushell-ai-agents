# Get server information
# Returns information about the Edge Server node.
def get_get_server_information [
 
] {
  mut header_params = []

  mut query_params = []

  curl_request  "GET" $"/"  $query_params  $header_params  null
}

# Get list of all database names
# Returns a list of all database names.
def get_get_list_of_all_database_names [
 
] {
  mut header_params = []

  mut query_params = []

  curl_request  "GET" $"/_all_dbs"  $query_params  $header_params  null
}

# List active replications only
# Get a list of all active tasks
def get_list_active_replications_only [
 
] {
  mut header_params = []

  mut query_params = []

  curl_request  "GET" $"/_active_tasks"  $query_params  $header_params  null
}

# Get status of all replications
# Gets the status of all replication tasks.
def get_get_status_of_all_replications [
 
] {
  mut header_params = []

  mut query_params = []

  curl_request  "GET" $"/_replicate"  $query_params  $header_params  null
}

# Start a replication
# Instructs Edge Server to initiate replication with another server, e.g. Sync Gateway.
def post_start_a_replication [
    body :  string ,  # source string - The source database name or URL. target string - The destination database name or URL. bidirectional boolean - Set to `true` for bidirectional push/pull replication. continuous boolean - Set to `true` for continuous replication. channels string - A Sync Gateway channel name. doc_ids string - A document ID. An object containing the following field:. This is the last field of the object.. .. trusted_root_certs string - The certificate data of an additional root certificate to be trusted. pinned_cert string - The certificate data of the server certificate. user string - Username for HTTP Basic auth to remote server. password string - Password for HTTP Basic auth to remote server. openid_token string - An OpenID Connect token for authentication. tls_client_cert string - Edge Server's client certificate for mTLS. tls_client_cert_key string - Private key of TLS client certificate.session_cookie string - A Sync Gateway session cookie for authentication. An object containing the following field:type string - Proxy type: `HTTP` or `HTTPS` (default: `HTTP`). host string - Hostname of proxy server. port number - Port number of proxy server. An object containing the following field:user string - Username for HTTP Basic auth to remote server. password string - Password for HTTP Basic auth to remote server. openid_token string - An OpenID Connect token for authentication. tls_client_cert string - Edge Server's client certificate for mTLS. tls_client_cert_key string - Private key of TLS client certificate. This is the last field of the object.. This is the last field of the object.
] {
  mut header_params = []

  mut query_params = []

  curl_request  "POST" $"/_replicate"  $query_params  $header_params  $body
}

# Get status of a replication
# Gets the status of the replication task with the given ID.
def get_get_status_of_a_replication [
    taskid :  string ,  # The ID of an active replication task.
] {
  mut header_params = []

  mut query_params = []

  curl_request  "GET" $"/_replicate/($taskid)"  $query_params  $header_params  null
}

# Stop replication
# Stops the replication task with the given ID.
def delete_stop_replication [
    taskid :  string ,  # The ID of an active replication task.
] {
  mut header_params = []

  mut query_params = []

  curl_request  "DELETE" $"/_replicate/($taskid)"  $query_params  $header_params  null
}

# Get database or keyspace information
# Retrieves information about a database or keyspace.
def get_get_database_or_keyspace_information [
    keyspace :  string ,  # The keyspace to run the operation against.  A keyspace is a dot-separated string, comprised of a database name, and optionally a named scope and collection.
] {
  mut header_params = []

  mut query_params = []

  curl_request  "GET" $"/($keyspace)"  $query_params  $header_params  null
}

# Create a document
# Creates a document with an automatically-generated document ID.
def put_create_a_document [
    body :  string ,  # 
    keyspace :  string ,  # The keyspace to run the operation against.  A keyspace is a dot-separated string, comprised of a database name, and optionally a named scope and collection.
] {
  mut header_params = []

  mut query_params = []

  curl_request  "PUT" $"/($keyspace)"  $query_params  $header_params  $body
}

# Get all documents in the keyspace
# Returns all documents in the database, based on the specified query parameters.
def get_get_all_documents_in_the_keyspace [
    keyspace :  string ,  # The keyspace to run the operation against.  A keyspace is a dot-separated string, comprised of a database name, and optionally a named scope and collection.
    --endkey :  string ,  # Stop returning records when this key is reached.
    --startkey :  string ,  # Return records starting with the specified key.
    --skip :  string ,  # Offset into the result rows returned. Combined with `limit` can be useful for paging.
    --limit :  string ,  # This limits the number of result rows returned. Using a value of `0` has the same effect as the value `1`.
    --keys :  string ,  # An array of document ID strings to filter by.
    --include_docs :  string ,  # Include the body associated with each document.
    --descending :  string ,  # Reverses sort order (descending document ID)
] {
  mut header_params = []

  mut query_params = []
  if ( $endkey != null) {
    $query_params = $query_params | append  { endkey : $endkey } 
  }
  if ( $startkey != null) {
    $query_params = $query_params | append  { startkey : $startkey } 
  }
  if ( $skip != null) {
    $query_params = $query_params | append  { skip : $skip } 
  }
  if ( $limit != null) {
    $query_params = $query_params | append  { limit : $limit } 
  }
  if ( $keys != null) {
    $query_params = $query_params | append  { keys : $keys } 
  }
  if ( $include_docs != null) {
    $query_params = $query_params | append  { include_docs : $include_docs } 
  }
  if ( $descending != null) {
    $query_params = $query_params | append  { descending : $descending } 
  }
  curl_request  "GET" $"/($keyspace)/_all_docs"  $query_params  $header_params  null
}

# Get all documents in the keyspace
# Returns all documents in the database, based on the parameters specified in the request body.
def post_get_all_documents_in_the_keyspace [
    body :  string ,  # descending boolean - Reverses sort order (descending document ID). include_docs boolean - Adds body of each doc. keys string - Limits results to the specified document IDs. limit number - Limits number of results. skip number - Offset into results. startkey string - Document ID to start at. endkey string - Document ID to end at (max value, or min if descending)
    keyspace :  string ,  # The keyspace to run the operation against.  A keyspace is a dot-separated string, comprised of a database name, and optionally a named scope and collection.
] {
  mut header_params = []

  mut query_params = []

  curl_request  "POST" $"/($keyspace)/_all_docs"  $query_params  $header_params  $body
}

# Check if any documents exist
# Returns a status code indicating whether any documents exist.
def head_check_if_any_documents_exist [
    keyspace :  string ,  # The keyspace to run the operation against.  A keyspace is a dot-separated string, comprised of a database name, and optionally a named scope and collection.
    --limit :  string ,  # This limits the number of result rows returned. Using a value of `0` has the same effect as the value `1`.
    --endkey :  string ,  # Stop returning records when this key is reached.
    --startkey :  string ,  # Return records starting with the specified key.
    --keys :  string ,  # An array of document ID strings to filter by.
    --include_docs :  string ,  # Include the body associated with each document.
] {
  mut header_params = []

  mut query_params = []
  if ( $limit != null) {
    $query_params = $query_params | append  { limit : $limit } 
  }
  if ( $endkey != null) {
    $query_params = $query_params | append  { endkey : $endkey } 
  }
  if ( $startkey != null) {
    $query_params = $query_params | append  { startkey : $startkey } 
  }
  if ( $keys != null) {
    $query_params = $query_params | append  { keys : $keys } 
  }
  if ( $include_docs != null) {
    $query_params = $query_params | append  { include_docs : $include_docs } 
  }
  curl_request  "HEAD" $"/($keyspace)/_all_docs"  $query_params  $header_params  null
}

# Bulk document operations
# Allows multiple documented to be created, updated or deleted in bulk.
# 
# To create a new document, add the body as an object in the `docs` array.
# A document ID is generated by Edge Server unless `_id` is specified.
# 
# To update an existing document, provide the document ID (`_id`) and revision ID (`_rev`) as well as the new body values.
# 
# To delete an existing document, provide the document ID (`_id`), revision ID (`_rev`), and set the deletion flag (`_deleted`) to true.
def post_bulk_document_operations [
    body :  string ,  # new_edits boolean - This controls whether to assign new revision identifiers to new edits (`true`) or use the existing ones (`false`).. An object containing the following field:_id string - document ID. _rev string - revision ID. This is the last field of the object.
    keyspace :  string ,  # The keyspace to run the operation against.  A keyspace is a dot-separated string, comprised of a database name, and optionally a named scope and collection.
] {
  mut header_params = []

  mut query_params = []

  curl_request  "POST" $"/($keyspace)/_bulk_docs"  $query_params  $header_params  $body
}

# Get changes list
# Retrieves a sorted list of changes made to documents in the database, in time order of application. Each document appears at most once, ordered by its most recent change, regardless of how many times it has been changed.
# 
# This request can be used to listen for update and modifications to the database for post processing or synchronization. A continuously connected changes feed is a reasonable approach for generating a real-time log for most applications.
def get_get_changes_list [
    keyspace :  string ,  # The keyspace to run the operation against.  A keyspace is a dot-separated string, comprised of a database name, and optionally a named scope and collection.
    --feed :  string ,  # The type of changes feed to use. 
    --timeout :  string ,  # This is the maximum period (in milliseconds) to wait for a change before the response is sent, even if there are no results. This is only applicable for `feed=longpoll` or `feed=continuous` changes feeds. Setting to 0 results in no timeout.
    --heartbeat :  string ,  # The interval (in milliseconds) to send an empty line (CRLF) in the response. This is to help prevent gateways from deciding the socket is idle and therefore closing it. This is only applicable to `feed=longpoll` or `feed=continuous`. This overrides any timeouts to keep the feed alive indefinitely. Setting to 0 results in no heartbeat. The maximum heartbeat can be set in the replication configuration.
    --doc_ids :  string ,  # A valid JSON array of document IDs to filter the documents in the response to only the documents specified. To use this option, the `filter` query option must be set to `_doc_ids` and the `feed` parameter must be `normal`. Also accepts a comma separated list of document IDs instead.
    --channels :  string ,  # A comma-separated list of channel names to filter the response to only the channels specified. To use this option, the `filter` query option must be set to `sync_gateway/bychannels`.
    --filter :  string ,  # Set a filter to either filter by channels or document IDs.
    --revocations :  string ,  # If true, revocation messages are sent on the changes feed.
    --include_docs :  string ,  # Include the body associated with each document.
    --active_only :  string ,  # Set true to exclude deleted documents and notifications for documents the user no longer has access to from the changes feed.
    --style :  string ,  # Controls whether to return the current winning revision (`main_only`) or all the leaf revision including conflicts and deleted former conflicts (`all_docs`).
    --since :  string ,  # Starts the results from the change immediately after the given sequence ID. Sequence IDs should be considered opaque; they come from the last_seq property of a prior response.
    --limit :  string ,  # Maximum number of changes to return.
] {
  mut header_params = []

  mut query_params = []
  if ( $feed != null) {
    $query_params = $query_params | append  { feed : $feed } 
  }
  if ( $timeout != null) {
    $query_params = $query_params | append  { timeout : $timeout } 
  }
  if ( $heartbeat != null) {
    $query_params = $query_params | append  { heartbeat : $heartbeat } 
  }
  if ( $doc_ids != null) {
    $query_params = $query_params | append  { doc_ids : $doc_ids } 
  }
  if ( $channels != null) {
    $query_params = $query_params | append  { channels : $channels } 
  }
  if ( $filter != null) {
    $query_params = $query_params | append  { filter : $filter } 
  }
  if ( $revocations != null) {
    $query_params = $query_params | append  { revocations : $revocations } 
  }
  if ( $include_docs != null) {
    $query_params = $query_params | append  { include_docs : $include_docs } 
  }
  if ( $active_only != null) {
    $query_params = $query_params | append  { active_only : $active_only } 
  }
  if ( $style != null) {
    $query_params = $query_params | append  { style : $style } 
  }
  if ( $since != null) {
    $query_params = $query_params | append  { since : $since } 
  }
  if ( $limit != null) {
    $query_params = $query_params | append  { limit : $limit } 
  }
  curl_request  "GET" $"/($keyspace)/_changes"  $query_params  $header_params  null
}

# Get changes list
# Retrieves a sorted list of changes made to documents in the database, in time order of application. Each document appears at most once, ordered by its most recent change, regardless of how many times it has been changed.
# 
# This request can be used to listen for update and modifications to the database for post processing or synchronization. A continuously connected changes feed is a reasonable approach for generating a real-time log for most applications.
def post_get_changes_list [
    body :  string ,  # limit string - Maximum number of changes to return.. style string - Controls whether to return the current winning revision (`main_only`) or all the leaf revision including conflicts and deleted former conflicts (`all_docs`).. active_only string - Set true to exclude deleted documents and notifications for documents the user no longer has access to from the changes feed.. include_docs boolean - Include the body associated with each document.. revocations string - If true, revocation messages are sent on the changes feed.. filter string - Set a filter to either filter by channels or document IDs.. channels string - A comma-separated list of channel names to filter the response to only the channels specified. To use this option, the `filter` query option must be set to `sync_gateway/bychannels`.. doc_ids string - A valid JSON array of document IDs to filter the documents in the response to only the documents specified. To use this option, the `filter` query option must be set to `_doc_ids` and the `feed` parameter must be `normal`.. heartbeat string - The interval (in milliseconds) to send an empty line (CRLF) in the response. This is to help prevent gateways from deciding the socket is idle and therefore closing it. This is only applicable to `feed=longpoll` or `feed=continuous`. This overrides any timeouts to keep the feed alive indefinitely. Setting to 0 results in no heartbeat. The maximum heartbeat can be set in the replication configuration.. timeout string - This is the maximum period (in milliseconds) to wait for a change before the response is sent, even if there are no results. This is only applicable for `feed=longpoll` or `feed=continuous` changes feeds. Setting to 0 results in no timeout.. feed string - The type of changes feed to use. 
    keyspace :  string ,  # The keyspace to run the operation against.  A keyspace is a dot-separated string, comprised of a database name, and optionally a named scope and collection.
] {
  mut header_params = []

  mut query_params = []

  curl_request  "POST" $"/($keyspace)/_changes"  $query_params  $header_params  $body
}

# Run an ad-hoc query
# Runs an ad-hoc query.
# Only possible when the database's `enable_adhoc_queries` property is true.
def post_run_an_adhoc_query [
    body :  string ,  # query string - SQL++ Query string. An object containing the following field:. This is the last field of the object.
    keyspace :  string ,  # The keyspace to run the operation against.  A keyspace is a dot-separated string, comprised of a database name, and optionally a named scope and collection.
] {
  mut header_params = []

  mut query_params = []

  curl_request  "POST" $"/($keyspace)/_query"  $query_params  $header_params  $body
}

# Run a pre-defined query
# Runs a pre-defined query as named by the database configuration's `query` object. If the query has parameters, they should be passed as query parameters, like `?key=value`.
def get_run_a_predefined_query [
    name :  string ,  # Name of the query as defined in the database configuration.
    keyspace :  string ,  # The keyspace to run the operation against.  A keyspace is a dot-separated string, comprised of a database name, and optionally a named scope and collection.
] {
  mut header_params = []

  mut query_params = []

  curl_request  "GET" $"/($keyspace)/_query/($name)"  $query_params  $header_params  null
}

# Run a pre-defined query
# Runs a pre-defined query as named by the database configuration's `query` object. If the query has parameters, they should be passed as JSON object in the request body.
def post_run_a_predefined_query [
    body :  string ,  # 
    name :  string ,  # Name of the query as defined in the database configuration.
    keyspace :  string ,  # The keyspace to run the operation against.  A keyspace is a dot-separated string, comprised of a database name, and optionally a named scope and collection.
] {
  mut header_params = []

  mut query_params = []

  curl_request  "POST" $"/($keyspace)/_query/($name)"  $query_params  $header_params  $body
}

# Get a document
# Retrieves a document from the database by its document ID.
def get_get_a_document [
    docid :  string ,  # The document ID to run the operation against.
    keyspace :  string ,  # The keyspace to run the operation against.  A keyspace is a dot-separated string, comprised of a database name, and optionally a named scope and collection.
    --revs_limit :  string ,  # Maximum number of revisions to return for each document.
    --revs_from :  string ,  # Trims the revision history to stop at the first revision in the provided list. If no match is found, the revisions are trimmed to the `revs_limit`.
    --rev :  string ,  # The document revision to target.
] {
  mut header_params = []

  mut query_params = []
  if ( $revs_limit != null) {
    $query_params = $query_params | append  { revs_limit : $revs_limit } 
  }
  if ( $revs_from != null) {
    $query_params = $query_params | append  { revs_from : $revs_from } 
  }
  if ( $rev != null) {
    $query_params = $query_params | append  { rev : $rev } 
  }
  curl_request  "GET" $"/($keyspace)/($docid)"  $query_params  $header_params  null
}

# Upsert a document
# Creates the specified document, if it does not already exist.
# If the specified document does exist, this request makes a new revision for the existing document.
# A revision ID must be provided if targeting an existing document.
# 
# You must specify a document ID for this endpoint.
# To let Edge Server generate the ID, use the `POST /{db}/` endpoint.
# 
# If the document already exists, the document content is replaced by the provided request body.
# Any existing fields which are not specified by the request body are removed in the new revision.
# 
# The maximum size for a document is 20MB.
def put_upsert_a_document [
    body :  string ,  # _id string - document ID. _rev string - revision ID of the document
    docid :  string ,  # The document ID to run the operation against.
    keyspace :  string ,  # The keyspace to run the operation against.  A keyspace is a dot-separated string, comprised of a database name, and optionally a named scope and collection.
    --If_Match :  string ,  # The revision ID to target.
    --rev :  string ,  # The document revision to target.
    --roundtrip :  string ,  # Block until document has been received by change cache.
] {
  mut header_params = []
  if ( $If_Match != null) {
    $header_params = $header_params | append  {  If_Match : $If_Match } 
  }
  mut query_params = []
  if ( $rev != null) {
    $query_params = $query_params | append  { rev : $rev } 
  }
  if ( $roundtrip != null) {
    $query_params = $query_params | append  { roundtrip : $roundtrip } 
  }
  curl_request  "PUT" $"/($keyspace)/($docid)"  $query_params  $header_params  $body
}

# Delete a document
# Deletes a document from the keyspace.
# A new revision is created so the database can track the deletion in synchronized copies.
# 
# A revision ID is required, either in the header or in the query parameters.
def delete_delete_a_document [
    docid :  string ,  # The document ID to run the operation against.
    keyspace :  string ,  # The keyspace to run the operation against.  A keyspace is a dot-separated string, comprised of a database name, and optionally a named scope and collection.
    --If_Match :  string ,  # The revision ID to target.
    --rev :  string ,  # The document revision to target.
] {
  mut header_params = []
  if ( $If_Match != null) {
    $header_params = $header_params | append  {  If_Match : $If_Match } 
  }
  mut query_params = []
  if ( $rev != null) {
    $query_params = $query_params | append  { rev : $rev } 
  }
  curl_request  "DELETE" $"/($keyspace)/($docid)"  $query_params  $header_params  null
}

# Check if a document exists
# Returns a status code indicating whether the document exists or not.
def head_check_if_a_document_exists [
    docid :  string ,  # The document ID to run the operation against.
    keyspace :  string ,  # The keyspace to run the operation against.  A keyspace is a dot-separated string, comprised of a database name, and optionally a named scope and collection.
    --revs_limit :  string ,  # Maximum number of revisions to return for each document.
    --revs_from :  string ,  # Trims the revision history to stop at the first revision in the provided list. If no match is found, the revisions are trimmed to the `revs_limit`.
    --rev :  string ,  # The document revision to target.
] {
  mut header_params = []

  mut query_params = []
  if ( $revs_limit != null) {
    $query_params = $query_params | append  { revs_limit : $revs_limit } 
  }
  if ( $revs_from != null) {
    $query_params = $query_params | append  { revs_from : $revs_from } 
  }
  if ( $rev != null) {
    $query_params = $query_params | append  { rev : $rev } 
  }
  curl_request  "HEAD" $"/($keyspace)/($docid)"  $query_params  $header_params  null
}

# Get a sub-document
# Retrieves a sub-document associated with the document.
def get_get_a_subdocument [
    key :  string ,  # The key of the object containing the sub-document.
    docid :  string ,  # The document ID to run the operation against.
    keyspace :  string ,  # The keyspace to run the operation against.  A keyspace is a dot-separated string, comprised of a database name, and optionally a named scope and collection.
    --rev :  string ,  # The document revision to target.
] {
  mut header_params = []

  mut query_params = []
  if ( $rev != null) {
    $query_params = $query_params | append  { rev : $rev } 
  }
  curl_request  "GET" $"/($keyspace)/($docid)/($key)"  $query_params  $header_params  null
}

# Create or update a sub-document
# Adds or updates a sub-document associated with the document. If the document does not exist, it is created and the sub-document is added to it.
# 
# If the sub-document already exists, the content of the existing sub-document is replaced in the new revision.
def put_create_or_update_a_subdocument [
    body :  string ,  # 
    key :  string ,  # The key of the object containing the sub-document.
    docid :  string ,  # The document ID to run the operation against.
    keyspace :  string ,  # The keyspace to run the operation against.  A keyspace is a dot-separated string, comprised of a database name, and optionally a named scope and collection.
    --rev :  string ,  # The existing document revision ID to modify. Required only when modifying an existing document.
] {
  mut header_params = []

  mut query_params = []
  if ( $rev != null) {
    $query_params = $query_params | append  { rev : $rev } 
  }
  curl_request  "PUT" $"/($keyspace)/($docid)/($key)"  $query_params  $header_params  $body
}

# Delete a sub-document
# Deletes a sub-document associated with the document.
# 
# If the sub-document exists, the sub-document is removed from the document.
def delete_delete_a_subdocument [
    key :  string ,  # The key of the object containing the sub-document.
    docid :  string ,  # The document ID to run the operation against.
    keyspace :  string ,  # The keyspace to run the operation against.  A keyspace is a dot-separated string, comprised of a database name, and optionally a named scope and collection.
    --rev :  string ,  # The existing document revision ID to modify.
] {
  mut header_params = []

  mut query_params = []
  if ( $rev != null) {
    $query_params = $query_params | append  { rev : $rev } 
  }
  curl_request  "DELETE" $"/($keyspace)/($docid)/($key)"  $query_params  $header_params  null
}
#$"  curl_request $\"\($env.CBES_BASE_URL\)($path)?\(\$query_params\)\" --headers \(\$header_params\) --method \"($method | str upcase)\" --username $env.CBES_USERNAME --password $env.CBES_PASSWORD --cacert $env.CBES_CACERT_PATH \($body\)",
def curl_request [           
    method: string,     # HTTP method (GET, POST, etc.)
    url: string,        # The target URL PATH
    query_params : list<record>,        
    headers: list<record>,          
    body: any
    --username: string,           # Username for basic auth
    --password: string,           # Password for basic auth
    --cacert: string,               # Path to client cert (.pem or .p12)
    --insecure,                   # Skip TLS verification
    --output: string              # Optional output file
] {
    let os = $nu.os-info.name
    
    mut query_part = ""
    mut query_parts = []
    if $query_params != null and ( $query_params | length ) > 0 {
        for $k in ( $query_params | transpose key value  ) {
            $query_parts ++= [$"($k.key)=($k.value)"]
        }
        
        $query_part = $query_parts | str join "&"
        $query_part = $query_part | prepend "?"
    } 


    mut args = ["-X", $method, $url]

    if $headers != null {
        for $k in ( $headers | transpose key value  ) {
            $args ++= ["-H", $"($k.key): ($k.value)"]
        }
    }

    if ($username != null and $password != null) {
        $args ++= ["-u", $"($username):($password)"]
    }

    if $data != null {
        $args ++= ["--data", $data]
    }

    if $cacert != null {
        if $os == "windows" and ($cacert | str ends-with ".p12") {
            # Use .p12 on Windows
            $args ++= ["--cert-type", "P12", "--cert", $cacert]
        } else if $cacert != null {
            # Use cert and key separately (PEM)
            $args ++= ["--cacert", $cacert ]
        }
    }

    if $insecure {
        $args ++= ["-k"]
    }

    if $output != null {
        $args ++= ["-o", $output]
    }

    let answer = ^curl ...$args
    $answer
}