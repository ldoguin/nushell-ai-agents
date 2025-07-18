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
    
    let $url = "https://cloudapi.cloud.couchbase.com" + $url

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
    
    $args ++= ["-H", $"Authorization: Bearer ($env.CAPELLA_API_KEY)"]

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
