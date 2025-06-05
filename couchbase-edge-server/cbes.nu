# Function to create certificate
def create_certificate [cn_expression : string, cert_path : string, key_path : string ] {
    couchbase-edge-server --create-cert $cn_expression $cert_path $key_path
}

# Adds a user account to the users file. You will be prompted for the password.
def add_user [
  users_file: string,
  username: string,
  --create = false,
  --role: string = "",
  --password: string = ""
] {
  mut cmd = ["couchbase-edge-server", "--add-user", $users_file, $username]

  if $create {
    $cmd = ($cmd | append "--create")
  }

  if $role != "" {
    $cmd = ($cmd | append "--role" | append $role)
  }

  if $password != "" {
    $cmd = ($cmd | append "--password" | append $password)
  }

  ^$cmd
}

# Regenerates a database's UUID; necessary if db file has been copied.
def reset_uuid [
  dbfile: string
] {
  couchbase-edge-server --reset-uuid $dbfile
}

# gets local couchbase-edge-server binary's version
def get_version [] {
  couchbase-edge-server --version
}


# Function to get server information
def get_server_info [] {
  curl_request $env.CBES_BASE_URL --method "GET" --username  $env.CBES_USERNAME --password  $env.CBES_PASSWORD --cacert  $env.CBES_CACERT_PATH
}

# Function to list all databases
def list_databases [] {
  curl_request $"($env.CBES_BASE_URL)/_all_dbs"  --method "GET" --username  $env.CBES_USERNAME --password  $env.CBES_PASSWORD --cacert  $env.CBES_CACERT_PATH
}

# Function to get information about a specific database or keyspace
def get_database_info [keyspace: string] {
  curl_request  $"($env.CBES_BASE_URL)/($keyspace)" --method "GET" --username  $env.CBES_USERNAME --password  $env.CBES_PASSWORD --cacert  $env.CBES_CACERT_PATH
}

# Function to create a new document with an auto-generated ID
def create_document [keyspace: string, document : string] {
  curl_request $"($env.CBES_BASE_URL)/($keyspace)" --method "POST" --username  $env.CBES_USERNAME --password  $env.CBES_PASSWORD  --headers { "Content-Type":  "application/json" } --data $document --cacert  $env.CBES_CACERT_PATH
}

# Function to retrieve a document by ID
def get_document [keyspace: string, doc_id: string] {
  curl_request $"($env.CBES_BASE_URL)/($keyspace)/($doc_id)" --method "GET" --username  $env.CBES_USERNAME --password  $env.CBES_PASSWORD --cacert  $env.CBES_CACERT_PATH
}

# Function to update or create a document with a specific ID
def upsert_document [keyspace: string, doc_id: string, document: record] {
  curl_request $"($env.CBES_BASE_URL)/($keyspace)/($doc_id)" --method "PUT" --username  $env.CBES_USERNAME --password  $env.CBES_PASSWORD  --headers { "Content-Type": "application/json" } --data ( $document | to json ) --cacert  $env.CBES_CACERT_PATH
}

# Function to delete a document by ID and revision
def delete_document [keyspace: string, doc_id: string, rev: string] {
  curl_request $"($env.CBES_BASE_URL)/($keyspace)/($doc_id)?rev=($rev)" --method "DELETE" --username  $env.CBES_USERNAME --password  $env.CBES_PASSWORD   --cacert  $env.CBES_CACERT_PATH
}

# Function to run an ad-hoc SQL++ query
def run_query [keyspace: string, query: string] {
  let body = { "query": $query }
  curl_request $"($env.CBES_BASE_URL)/($keyspace)/_query" --method "POST" --username  $env.CBES_USERNAME --password  $env.CBES_PASSWORD  --headers { "Content-Type": "application/json" } --data (  $body | to json ) --cacert  $env.CBES_CACERT_PATH
}

# Function to get changes feed
def get_changes [keyspace: string] {
  curl_request $"($env.CBES_BASE_URL)/($keyspace)/_changes" --method "GET" --username  $env.CBES_USERNAME --password  $env.CBES_PASSWORD  --cacert  $env.CBES_CACERT_PATH
}

# Function to start a replication
def start_replication [replication_id: string, config: record] {
  curl_request $"($env.CBES_BASE_URL)/_replicate/($replication_id)" --method "POST" --username  $env.CBES_USERNAME --password  $env.CBES_PASSWORD  --headers { "Content-Type": "application/json" } --data ( $config | to json ) --cacert  $env.CBES_CACERT_PATH
}

# Function to get replication status
def get_replication_status [replication_id: string] {
  curl_request $"($env.CBES_BASE_URL)/_replicate/($replication_id)" --method "GET" --username  $env.CBES_USERNAME --password  $env.CBES_PASSWORD --cacert  $env.CBES_CACERT_PATH
}

# Function to stop a replication
def stop_replication [replication_id: string] {
  curl_request  $"($env.CBES_BASE_URL)/_replicate/($replication_id)" --method "DELETE" --username  $env.CBES_USERNAME --password  $env.CBES_PASSWORD --cacert  $env.CBES_CACERT_PATH
}

# Save this as curl_request.nu
def curl_request [
    url: string,                   # The target URL
    --method: string = "GET",     # HTTP method (GET, POST, etc.)
    --headers: record,            # Custom headers as a record
    --data: string,               # Request body
    --username: string,           # Username for basic auth
    --password: string,           # Password for basic auth
    --cacert: string,               # Path to client cert (.pem or .p12)
    --insecure,                   # Skip TLS verification
    --output: string              # Optional output file
] {
    let os = $nu.os-info.name

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
