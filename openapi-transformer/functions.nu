# Get server information
# Returns information about the Edge Server node.
def get_get_server_information [
 tool_args 
] {
  mut header_params = []

  mut query_params = []


  curl_request  "GET" $"/"  $query_params  $header_params  null
}

# Get list of all database names
# Returns a list of all database names.
def get_get_list_of_all_database_names [
 tool_args 
] {
  mut header_params = []

  mut query_params = []


  curl_request  "GET" $"/_all_dbs"  $query_params  $header_params  null
}

# List active replications only
# Get a list of all active tasks
def get_list_active_replications_only [
 tool_args 
] {
  mut header_params = []

  mut query_params = []


  curl_request  "GET" $"/_active_tasks"  $query_params  $header_params  null
}

# Get status of all replications
# Gets the status of all replication tasks.
def get_get_status_of_all_replications [
 tool_args 
] {
  mut header_params = []

  mut query_params = []


  curl_request  "GET" $"/_replicate"  $query_params  $header_params  null
}

# Start a replication
# Instructs Edge Server to initiate replication with another server, e.g. Sync Gateway.
def post_start_a_replication [
 tool_args 
] {
  mut header_params = []

  mut query_params = []


  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "POST" $"/_replicate"  $query_params  $header_params  $body
}

# Get status of a replication
# Gets the status of the replication task with the given ID.
def get_get_status_of_a_replication [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  taskid =  ( $tool_args | get taskid ) 
  curl_request  "GET" $"/_replicate/($taskid)"  $query_params  $header_params  null
}

# Stop replication
# Stops the replication task with the given ID.
def delete_stop_replication [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  taskid =  ( $tool_args | get taskid ) 
  curl_request  "DELETE" $"/_replicate/($taskid)"  $query_params  $header_params  null
}

# Get database or keyspace information
# Retrieves information about a database or keyspace.
def get_get_database_or_keyspace_information [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  keyspace =  ( $tool_args | get keyspace ) 
  curl_request  "GET" $"/($keyspace)"  $query_params  $header_params  null
}

# Create a document
# Creates a document with an automatically-generated document ID.
def put_create_a_document [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  keyspace =  ( $tool_args | get keyspace ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "POST" $"/($keyspace)"  $query_params  $header_params  $body
}

# Get all documents in the keyspace
# Returns all documents in the database, based on the specified query parameters.
def get_get_all_documents_in_the_keyspace [
 tool_args 
] {
  mut header_params = []

  mut query_params = []
  if ( ( $tool_args | get -i descending ) != null ) {
    $query_params = $query_params | append  { descending : ( $tool_args | get descending ) } 
  }
  if ( ( $tool_args | get -i include_docs ) != null ) {
    $query_params = $query_params | append  { include_docs : ( $tool_args | get include_docs ) } 
  }
  if ( ( $tool_args | get -i keys ) != null ) {
    $query_params = $query_params | append  { keys : ( $tool_args | get keys ) } 
  }
  if ( ( $tool_args | get -i limit ) != null ) {
    $query_params = $query_params | append  { limit : ( $tool_args | get limit ) } 
  }
  if ( ( $tool_args | get -i skip ) != null ) {
    $query_params = $query_params | append  { skip : ( $tool_args | get skip ) } 
  }
  if ( ( $tool_args | get -i startkey ) != null ) {
    $query_params = $query_params | append  { startkey : ( $tool_args | get startkey ) } 
  }
  if ( ( $tool_args | get -i endkey ) != null ) {
    $query_params = $query_params | append  { endkey : ( $tool_args | get endkey ) } 
  }
  let  keyspace =  ( $tool_args | get keyspace ) 
  curl_request  "GET" $"/($keyspace)/_all_docs"  $query_params  $header_params  null
}

# Get all documents in the keyspace
# Returns all documents in the database, based on the parameters specified in the request body.
def post_get_all_documents_in_the_keyspace [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  keyspace =  ( $tool_args | get keyspace ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "POST" $"/($keyspace)/_all_docs"  $query_params  $header_params  $body
}

# Check if any documents exist
# Returns a status code indicating whether any documents exist.
def head_check_if_any_documents_exist [
 tool_args 
] {
  mut header_params = []

  mut query_params = []
  if ( ( $tool_args | get -i include_docs ) != null ) {
    $query_params = $query_params | append  { include_docs : ( $tool_args | get include_docs ) } 
  }
  if ( ( $tool_args | get -i keys ) != null ) {
    $query_params = $query_params | append  { keys : ( $tool_args | get keys ) } 
  }
  if ( ( $tool_args | get -i startkey ) != null ) {
    $query_params = $query_params | append  { startkey : ( $tool_args | get startkey ) } 
  }
  if ( ( $tool_args | get -i endkey ) != null ) {
    $query_params = $query_params | append  { endkey : ( $tool_args | get endkey ) } 
  }
  if ( ( $tool_args | get -i limit ) != null ) {
    $query_params = $query_params | append  { limit : ( $tool_args | get limit ) } 
  }
  let  keyspace =  ( $tool_args | get keyspace ) 
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
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  keyspace =  ( $tool_args | get keyspace ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "POST" $"/($keyspace)/_bulk_docs"  $query_params  $header_params  $body
}

# Get changes list
# Retrieves a sorted list of changes made to documents in the database, in time order of application. Each document appears at most once, ordered by its most recent change, regardless of how many times it has been changed.
# 
# This request can be used to listen for update and modifications to the database for post processing or synchronization. A continuously connected changes feed is a reasonable approach for generating a real-time log for most applications.
def get_get_changes_list [
 tool_args 
] {
  mut header_params = []

  mut query_params = []
  if ( ( $tool_args | get -i limit ) != null ) {
    $query_params = $query_params | append  { limit : ( $tool_args | get limit ) } 
  }
  if ( ( $tool_args | get -i since ) != null ) {
    $query_params = $query_params | append  { since : ( $tool_args | get since ) } 
  }
  if ( ( $tool_args | get -i style ) != null ) {
    $query_params = $query_params | append  { style : ( $tool_args | get style ) } 
  }
  if ( ( $tool_args | get -i active_only ) != null ) {
    $query_params = $query_params | append  { active_only : ( $tool_args | get active_only ) } 
  }
  if ( ( $tool_args | get -i include_docs ) != null ) {
    $query_params = $query_params | append  { include_docs : ( $tool_args | get include_docs ) } 
  }
  if ( ( $tool_args | get -i revocations ) != null ) {
    $query_params = $query_params | append  { revocations : ( $tool_args | get revocations ) } 
  }
  if ( ( $tool_args | get -i filter ) != null ) {
    $query_params = $query_params | append  { filter : ( $tool_args | get filter ) } 
  }
  if ( ( $tool_args | get -i channels ) != null ) {
    $query_params = $query_params | append  { channels : ( $tool_args | get channels ) } 
  }
  if ( ( $tool_args | get -i doc_ids ) != null ) {
    $query_params = $query_params | append  { doc_ids : ( $tool_args | get doc_ids ) } 
  }
  if ( ( $tool_args | get -i heartbeat ) != null ) {
    $query_params = $query_params | append  { heartbeat : ( $tool_args | get heartbeat ) } 
  }
  if ( ( $tool_args | get -i timeout ) != null ) {
    $query_params = $query_params | append  { timeout : ( $tool_args | get timeout ) } 
  }
  if ( ( $tool_args | get -i feed ) != null ) {
    $query_params = $query_params | append  { feed : ( $tool_args | get feed ) } 
  }
  let  keyspace =  ( $tool_args | get keyspace ) 
  curl_request  "GET" $"/($keyspace)/_changes"  $query_params  $header_params  null
}

# Get changes list
# Retrieves a sorted list of changes made to documents in the database, in time order of application. Each document appears at most once, ordered by its most recent change, regardless of how many times it has been changed.
# 
# This request can be used to listen for update and modifications to the database for post processing or synchronization. A continuously connected changes feed is a reasonable approach for generating a real-time log for most applications.
def post_get_changes_list [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  keyspace =  ( $tool_args | get keyspace ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "POST" $"/($keyspace)/_changes"  $query_params  $header_params  $body
}

# Run an ad-hoc query
# Runs an ad-hoc query.
# Only possible when the database's `enable_adhoc_queries` property is true.
def post_run_an_adhoc_query [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  keyspace =  ( $tool_args | get keyspace ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "POST" $"/($keyspace)/_query"  $query_params  $header_params  $body
}

# Run a pre-defined query
# Runs a pre-defined query as named by the database configuration's `query` object. If the query has parameters, they should be passed as query parameters, like `?key=value`.
def get_run_a_predefined_query [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  keyspace =  ( $tool_args | get keyspace ) 
   let  name =  ( $tool_args | get name ) 
  curl_request  "GET" $"/($keyspace)/_query/($name)"  $query_params  $header_params  null
}

# Run a pre-defined query
# Runs a pre-defined query as named by the database configuration's `query` object. If the query has parameters, they should be passed as JSON object in the request body.
def post_run_a_predefined_query [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  keyspace =  ( $tool_args | get keyspace ) 
   let  name =  ( $tool_args | get name ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "POST" $"/($keyspace)/_query/($name)"  $query_params  $header_params  $body
}

# Get a document
# Retrieves a document from the database by its document ID.
def get_get_a_document [
 tool_args 
] {
  mut header_params = []

  mut query_params = []
  if ( ( $tool_args | get -i rev ) != null ) {
    $query_params = $query_params | append  { rev : ( $tool_args | get rev ) } 
  }
  if ( ( $tool_args | get -i revs_from ) != null ) {
    $query_params = $query_params | append  { revs_from : ( $tool_args | get revs_from ) } 
  }
  if ( ( $tool_args | get -i revs_limit ) != null ) {
    $query_params = $query_params | append  { revs_limit : ( $tool_args | get revs_limit ) } 
  }
  let  keyspace =  ( $tool_args | get keyspace ) 
   let  docid =  ( $tool_args | get docid ) 
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
 tool_args 
] {
  mut header_params = []
  if ( ( $tool_args | get -i If-Match ) != null ) {
    $header_params = $header_params | append  { If-Match : ( $tool_args | get If-Match ) } 
  }
  mut query_params = []
  if ( ( $tool_args | get -i roundtrip ) != null ) {
    $query_params = $query_params | append  { roundtrip : ( $tool_args | get roundtrip ) } 
  }
  if ( ( $tool_args | get -i rev ) != null ) {
    $query_params = $query_params | append  { rev : ( $tool_args | get rev ) } 
  }
  let  keyspace =  ( $tool_args | get keyspace ) 
   let  docid =  ( $tool_args | get docid ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "PUT" $"/($keyspace)/($docid)"  $query_params  $header_params  $body
}

# Delete a document
# Deletes a document from the keyspace.
# A new revision is created so the database can track the deletion in synchronized copies.
# 
# A revision ID is required, either in the header or in the query parameters.
def delete_delete_a_document [
 tool_args 
] {
  mut header_params = []
  if ( ( $tool_args | get -i If-Match ) != null ) {
    $header_params = $header_params | append  { If-Match : ( $tool_args | get If-Match ) } 
  }
  mut query_params = []
  if ( ( $tool_args | get -i rev ) != null ) {
    $query_params = $query_params | append  { rev : ( $tool_args | get rev ) } 
  }
  let  keyspace =  ( $tool_args | get keyspace ) 
   let  docid =  ( $tool_args | get docid ) 
  curl_request  "DELETE" $"/($keyspace)/($docid)"  $query_params  $header_params  null
}

# Check if a document exists
# Returns a status code indicating whether the document exists or not.
def head_check_if_a_document_exists [
 tool_args 
] {
  mut header_params = []

  mut query_params = []
  if ( ( $tool_args | get -i rev ) != null ) {
    $query_params = $query_params | append  { rev : ( $tool_args | get rev ) } 
  }
  if ( ( $tool_args | get -i revs_from ) != null ) {
    $query_params = $query_params | append  { revs_from : ( $tool_args | get revs_from ) } 
  }
  if ( ( $tool_args | get -i revs_limit ) != null ) {
    $query_params = $query_params | append  { revs_limit : ( $tool_args | get revs_limit ) } 
  }
  let  keyspace =  ( $tool_args | get keyspace ) 
   let  docid =  ( $tool_args | get docid ) 
  curl_request  "HEAD" $"/($keyspace)/($docid)"  $query_params  $header_params  null
}

# Get a sub-document
# Retrieves a sub-document associated with the document.
def get_get_a_subdocument [
 tool_args 
] {
  mut header_params = []

  mut query_params = []
  if ( ( $tool_args | get -i rev ) != null ) {
    $query_params = $query_params | append  { rev : ( $tool_args | get rev ) } 
  }
  let  keyspace =  ( $tool_args | get keyspace ) 
   let  docid =  ( $tool_args | get docid ) 
   let  key =  ( $tool_args | get key ) 
  curl_request  "GET" $"/($keyspace)/($docid)/($key)"  $query_params  $header_params  null
}

# Create or update a sub-document
# Adds or updates a sub-document associated with the document. If the document does not exist, it is created and the sub-document is added to it.
# 
# If the sub-document already exists, the content of the existing sub-document is replaced in the new revision.
def put_create_or_update_a_subdocument [
 tool_args 
] {
  mut header_params = []

  mut query_params = []
  if ( ( $tool_args | get -i rev ) != null ) {
    $query_params = $query_params | append  { rev : ( $tool_args | get rev ) } 
  }
  let  keyspace =  ( $tool_args | get keyspace ) 
   let  docid =  ( $tool_args | get docid ) 
   let  key =  ( $tool_args | get key ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "PUT" $"/($keyspace)/($docid)/($key)"  $query_params  $header_params  $body
}

# Delete a sub-document
# Deletes a sub-document associated with the document.
# 
# If the sub-document exists, the sub-document is removed from the document.
def delete_delete_a_subdocument [
 tool_args 
] {
  mut header_params = []

  mut query_params = []
  if ( ( $tool_args | get -i rev ) != null ) {
    $query_params = $query_params | append  { rev : ( $tool_args | get rev ) } 
  }
  let  keyspace =  ( $tool_args | get keyspace ) 
   let  docid =  ( $tool_args | get docid ) 
   let  key =  ( $tool_args | get key ) 
  curl_request  "DELETE" $"/($keyspace)/($docid)/($key)"  $query_params  $header_params  null
}
#$"  curl_request $\"\($env.CBES_BASE_URL\)($path)?\(\$query_params\)\" --headers \(\$header_params\) --method \"($method | str upcase)\" --username $env.CBES_USERNAME --password $env.CBES_PASSWORD --cacert $env.CBES_CACERT_PATH \($body\)",
def curl_request [           
    method: string,     # HTTP method (GET, POST, etc.)
    url: string,        # The target URL PATH
    query_params,        
    headers,          
    body: any
    --username: string,           # Username for basic auth
    --password: string,           # Password for basic auth
    --cacert: string,               # Path to client cert (.pem or .p12)
    --insecure,                   # Skip TLS verification
    --output: string              # Optional output file
] {
    let os = $nu.os-info.name
    
    let $url = ( if ( $env.CBES_BASE_URL? != null) {
        $env.CBES_BASE_URL + $url
    } else {
        $url 
    }
    )
    
    let $username = ( if ( $env.CBES_USERNAME? != null) {
        $env.CBES_USERNAME
    } else {
        $username 
    }
    )

     let $password = ( if ( $env.CBES_PASSWORD? != null) {
        $env.CBES_PASSWORD
    } else {
        $password 
    }
    )

     let $cacert = ( if ( $env.CBES_CACERT_PATH? != null) {
        $env.CBES_CACERT_PATH
    } else {
        $cacert 
    }
    )

    mut query_part = ""
    mut query_parts = []
    if $query_params != null and ( $query_params | length ) > 0 {
        $query_parts  = $query_params  | each { |k|
            $"($k | columns | get 0 )=($k | values | get 0  )"
        }
        $query_part = $query_parts | str join "&"
    }

    mut url = $url
    if ($query_parts | length) > 0 {
        $url = $url + "?" + $query_part
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
 
    if $body != null {
        $args ++= ["--data", $"($body)"]
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