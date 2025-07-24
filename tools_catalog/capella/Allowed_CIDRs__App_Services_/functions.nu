# Get Cloud Accounts
# Fetches the cloud account ID associated with the organization. Use this account ID when adding CMEK to other AWS databases in your organization.
# 
# To learn more, see [CMEK at Rest](https://docs.couchbase.com/cloud/security/cmek.html).
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
#   - Organization Owner
#   - Project Creator
#   - Organization Member
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_getcloudaccounts [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/cloudAccounts"  $query_params  $header_params  null
}

# Create API Key
# Creates a new API key under an organization.
# 
# Organization Owners can create Organization and Project scoped API keys.
# 
# Project Owner and Project Creator can create project scoped keys.
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def post_postorganizationapikeys [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "POST" $"/v4/organizations/($organizationId)/apikeys"  $query_params  $header_params  $body
}

# List API keys
# Lists all the API keys under an organization.
# 
# Organization Owners can list all the API keys inside the Organization.
# 
# Organization Members and Project Creators can list all the Project scoped API key for which they are Project Owner.
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_listorganizationapikeys [
 tool_args 
] {
  mut header_params = []

  mut query_params = []
  if ( ( $tool_args | get -i page ) != null ) {
    $query_params = $query_params | append  { page : ( $tool_args | get page ) } 
  }
  if ( ( $tool_args | get -i perPage ) != null ) {
    $query_params = $query_params | append  { perPage : ( $tool_args | get perPage ) } 
  }
  if ( ( $tool_args | get -i sortBy ) != null ) {
    $query_params = $query_params | append  { sortBy : ( $tool_args | get sortBy ) } 
  }
  if ( ( $tool_args | get -i sortDirection ) != null ) {
    $query_params = $query_params | append  { sortDirection : ( $tool_args | get sortDirection ) } 
  }
  let  organizationId =  ( $tool_args | get organizationId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/apikeys"  $query_params  $header_params  null
}

# Get API Key
# Fetches the details of the given API key under an organization.
# 
# Organization Owners can get any API key inside the Organization.
# 
# Organization Members and Project Creator can get any Project scoped API key for which they are Project Owner.
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_getorganizationapikeybyaccesskey [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  ApiKeyId =  ( $tool_args | get ApiKeyId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/apikeys/($ApiKeyId)"  $query_params  $header_params  null
}

# Delete API Key
# Deletes the given API key under an organization.
# 
# Organization Owners can delete any API key inside the Organization.
# 
# Organization Members and Project Creator can delete any Project scoped API key for which they are Project Owner.
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def delete_deleteorganizationapikey [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  ApiKeyId =  ( $tool_args | get ApiKeyId ) 
  curl_request  "DELETE" $"/v4/organizations/($organizationId)/apikeys/($ApiKeyId)"  $query_params  $header_params  null
}

# Rotate API Key
# Rotate the secret of a given API key under an organization.
# 
# Organization Owners can rotate any API key inside the Organization.
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def post_postorganizationapikeyrotate [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  ApiKeyId =  ( $tool_args | get ApiKeyId ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "POST" $"/v4/organizations/($organizationId)/apikeys/($ApiKeyId)/rotate"  $query_params  $header_params  $body
}

# Create Project
# Creates a new project under the organization.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Creator
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def post_postproject [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "POST" $"/v4/organizations/($organizationId)/projects"  $query_params  $header_params  $body
}

# List Project
# Lists all the projects under the organization.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# - Project Viewer
# - Database Data Reader/Writer
# - Database Data Reader
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_listprojects [
 tool_args 
] {
  mut header_params = []

  mut query_params = []
  if ( ( $tool_args | get -i page ) != null ) {
    $query_params = $query_params | append  { page : ( $tool_args | get page ) } 
  }
  if ( ( $tool_args | get -i perPage ) != null ) {
    $query_params = $query_params | append  { perPage : ( $tool_args | get perPage ) } 
  }
  if ( ( $tool_args | get -i sortBy ) != null ) {
    $query_params = $query_params | append  { sortBy : ( $tool_args | get sortBy ) } 
  }
  if ( ( $tool_args | get -i sortDirection ) != null ) {
    $query_params = $query_params | append  { sortDirection : ( $tool_args | get sortDirection ) } 
  }
  let  organizationId =  ( $tool_args | get organizationId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects"  $query_params  $header_params  null
}

# Get Project
# Fetches the details of the given project.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# - Project Viewer
# - Database Data Reader/Writer
# - Database Data Reader
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_getprojectbyid [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)"  $query_params  $header_params  null
}

# Update Project
# Update project name and or project description.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def put_putproject [
 tool_args 
] {
  mut header_params = []
  if ( ( $tool_args | get -i If-Match ) != null ) {
    $header_params = $header_params | append  { If-Match : ( $tool_args | get If-Match ) } 
  }
  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "PUT" $"/v4/organizations/($organizationId)/projects/($projectId)"  $query_params  $header_params  $body
}

# Delete Project
# Deletes an existing project.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def delete_deleteprojectbyid [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
  curl_request  "DELETE" $"/v4/organizations/($organizationId)/projects/($projectId)"  $query_params  $header_params  null
}

# Create Free Tier Cluster
# Creates a free tier cluster.  This is a 1 node cluster than only runs data, query, index and search services.
# 
# You can have at most 1 free tier cluster per tenant.
# 
# The following features are not available for free tier clusters:
#   - backup/restore
#   - private endpoint service
#   - network peering
#   - audit logs
#   - alert integration
#   - CMEK
#   - on/off schedule
# 
# Only cluster name, description, CSP, region and CIDR are configurable.
# 
# There are limited regions available based on CSP:
#   a. for AWS they are us-east-2, eu-west-1, ap-southeast-1
#   b. for GCP they are us-central1, europe-west1, asia-east1
#   c. for Azure they are eastus, swedencentral, koreacentral
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def post_createfreetiercluster [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "POST" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/freeTier"  $query_params  $header_params  $body
}

# Create Cluster
# Creates a new Couchbase Capella provisioned cluster.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def post_postcluster [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "POST" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters"  $query_params  $header_params  $body
}

# List Clusters
# Lists all the clusters under the organization.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# - Project Viewer
# - Database Data Reader/Writer
# - Database Data Reader
# 
# Returned set of clusters is reduced to what the caller has access to view.
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_listclusters [
 tool_args 
] {
  mut header_params = []

  mut query_params = []
  if ( ( $tool_args | get -i page ) != null ) {
    $query_params = $query_params | append  { page : ( $tool_args | get page ) } 
  }
  if ( ( $tool_args | get -i perPage ) != null ) {
    $query_params = $query_params | append  { perPage : ( $tool_args | get perPage ) } 
  }
  if ( ( $tool_args | get -i sortBy ) != null ) {
    $query_params = $query_params | append  { sortBy : ( $tool_args | get sortBy ) } 
  }
  if ( ( $tool_args | get -i sortDirection ) != null ) {
    $query_params = $query_params | append  { sortDirection : ( $tool_args | get sortDirection ) } 
  }
  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters"  $query_params  $header_params  null
}

# Get Free Tier Cluster
# Get details of the free tier cluster.
# 
# While only cluster name, description, CSP, region and CIDR are configurable, other read only fields are retrieved.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
#  - Organization Owner
#  - Project Owner
#  - Project Manager
#  - Project Viewer
#  - Database Data Reader/Writer
#  - Database Data Reader
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_getfreetiercluster [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/freeTier/($clusterId)"  $query_params  $header_params  null
}

# Update Free Tier Cluster
# Updates an existing free tier cluster.  Only name and description are configurable.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def put_updatefreetiercluster [
 tool_args 
] {
  mut header_params = []
  if ( ( $tool_args | get -i If-Match ) != null ) {
    $header_params = $header_params | append  { If-Match : ( $tool_args | get If-Match ) } 
  }
  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "PUT" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/freeTier/($clusterId)"  $query_params  $header_params  $body
}

# Delete Free Tier Cluster
# Deletes an existing free tier cluster.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def delete_deletefreetiercluster [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
  curl_request  "DELETE" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/freeTier/($clusterId)"  $query_params  $header_params  null
}

# Get Cluster
# Fetches the details of the given cluster.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
#  - Organization Owner
#  - Project Owner
#  - Project Manager
#  - Project Viewer
#  - Database Data Reader/Writer
#  - Database Data Reader
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_getcluster [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)"  $query_params  $header_params  null
}

# Update Cluster
# Updates an existing cluster.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def put_putcluster [
 tool_args 
] {
  mut header_params = []
  if ( ( $tool_args | get -i If-Match ) != null ) {
    $header_params = $header_params | append  { If-Match : ( $tool_args | get If-Match ) } 
  }
  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "PUT" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)"  $query_params  $header_params  $body
}

# Delete Cluster
# Deletes an existing cluster.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def delete_deletecluster [
 tool_args 
] {
  mut header_params = []

  mut query_params = []
  if ( ( $tool_args | get -i retainsnapshotbackups ) != null ) {
    $query_params = $query_params | append  { retainsnapshotbackups : ( $tool_args | get retainsnapshotbackups ) } 
  }
  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
  curl_request  "DELETE" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)"  $query_params  $header_params  null
}

# Turn On Free Tier Cluster
# Turn free tier cluster on.  It will also turn on the linked app services, if any.
# 
# In order to access this endpoint, the provided API key must have at least one of the roles referenced below:
# - Organization Owner
# - Project Owner
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def post_freetierclusteron [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
  curl_request  "POST" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/freeTier/($clusterId)/activationState"  $query_params  $header_params  null
}

# Turn Off Free Tier Cluster
# Turn free tier cluster off.
# 
# - Turning off your cluster turns off the compute for your cluster but the storage remains.
# All of the data, schema (buckets, scopes, and collections), and indexes remain, as well as cluster configuration, including users and allow lists.
# 
# - Turning off cluster will also turn off any linked app services.
# 
#  In order to access this endpoint, the provided API key must have at least one of the roles referenced below:
# - Organization Owner
# - Project Owner
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def delete_freetierclusteroff [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
  curl_request  "DELETE" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/freeTier/($clusterId)/activationState"  $query_params  $header_params  null
}

# Turn On Cluster
# Turn cluster on.
# 
# In order to access this endpoint, the provided API key must have at least one of the roles referenced below:
# - Organization Owner
# - Project Owner
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def post_clusteron [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "POST" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/activationState"  $query_params  $header_params  $body
}

# Turn Off Cluster
# Turn cluster off.
# 
# - Turning off your cluster turns off the compute for your cluster but the storage remains.
# All of the data, schema (buckets, scopes, and collections), and indexes remain, as well as cluster configuration, including users and allow lists.
# 
# - Turning off cluster will also turn off any linked app services.
# 
#  In order to access this endpoint, the provided API key must have at least one of the roles referenced below:
# - Organization Owner
# - Project Owner
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def delete_clusteroff [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
  curl_request  "DELETE" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/activationState"  $query_params  $header_params  null
}

# Create Cluster On/Off schedule
# This provides the means to add a new cluster on/off schedule.
# 
# In order to access this endpoint, the provided API key must have at least one of the roles referenced below:
# - Organization Owner
# - Project Owner
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def post_postonoffschedule [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "POST" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/onOffSchedule"  $query_params  $header_params  $body
}

# Get Cluster On/Off schedule
# Fetches the details of the cluster on/off schedule for the given cluster.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
#  - Organization Owner
#  - Project Owner
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_getonoffschedule [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/onOffSchedule"  $query_params  $header_params  null
}

# Update Cluster On/Off schedule
# This provides the means to update an existing cluster on/off schedule.
# 
# In order to access this endpoint, the provided API key must have at least one of the roles referenced below:
# - Organization Owner
# - Project Owner
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def put_putonoffschedule [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "PUT" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/onOffSchedule"  $query_params  $header_params  $body
}

# Delete Cluster On/Off schedule
# Deletes the cluster on/off schedule for the given cluster.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def delete_deleteonoffschedule [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
  curl_request  "DELETE" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/onOffSchedule"  $query_params  $header_params  null
}

# Update Cluster Audit Log Configuration
# Updates the audit log configuration for the cluster.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
#   - Organization Owner
#   - Project Owner
#   - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def put_putclusterauditsettings [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "PUT" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/auditLog"  $query_params  $header_params  $body
}

# Get Cluster Audit Log Configuration
# Fetches information on whether audit logging is enabled, and which event IDs are enabled.
# 
# To learn more about cluster audit logs, please refer to [audit management](https://docs.couchbase.com/cloud/security/audit-management.html).
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
#  - Organization Owner
#  - Project Owner
#  - Project Manager
#  - Project Viewer
#  - Database Data Reader/Writer
#  - Database Data Reader
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_getclusterauditsettings [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/auditLog"  $query_params  $header_params  null
}

# List Filterable Audit Log Events
# Retrieves a list of audit event IDs. The list of filterable event IDs can be specified while configuring audit log for cluster.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
#  - Organization Owner
#  - Project Owner
#  - Project Manager
#  - Project Viewer
#  - Database Data Reader/Writer
#  - Database Data Reader
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_getauditlogeventids [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/auditLogEvents"  $query_params  $header_params  null
}

# Create Cluster Audit Log Export job
# Creates a new audit log export job.
# 
# Audit Logs for the last 30 days can be requested, otherwise they are purged. A pre-signed URL to a s3 bucket location is returned, which is used to download these audit logs.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
#   - Organization Owner
#   - Project Owner
#   - Project Manager
#   - Project Viewer
#   - Database Data Reader/Writer
#   - Database Data Reader
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def post_postauditlogexport [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "POST" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/auditLogExports"  $query_params  $header_params  $body
}

# List Cluster Audit Log Export Jobs
# Lists all the audit log export jobs and shows the status for each job.
# 
# It will show the pre-signed URL if the export was successful, a failure error if it was unsuccessful or a message saying no audit logs available if there were no audit logs found.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
#  - Organization Owner
#  - Project Owner
#  - Project Manager
#  - Project Viewer
#  - Database Data Reader/Writer
#  - Database Data Reader
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_listauditlogexports [
 tool_args 
] {
  mut header_params = []

  mut query_params = []
  if ( ( $tool_args | get -i page ) != null ) {
    $query_params = $query_params | append  { page : ( $tool_args | get page ) } 
  }
  if ( ( $tool_args | get -i perPage ) != null ) {
    $query_params = $query_params | append  { perPage : ( $tool_args | get perPage ) } 
  }
  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/auditLogExports"  $query_params  $header_params  null
}

# Get Cluster Audit Log Export
# Fetches the status of a single audit log export job.
# 
# It will show the pre-signed URL if the export was successful, a failure error if it was unsuccessful or a message saying no audit logs available if there were no audit logs found during the given timeframe.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
#  - Organization Owner
#  - Project Owner
#  - Project Manager
#  - Project Viewer
#  - Database Data Reader/Writer
#  - Database Data Reader
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_getauditlogexport [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  auditLogExportId =  ( $tool_args | get auditLogExportId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/auditLogExports/($auditLogExportId)"  $query_params  $header_params  null
}

# Create Key Metadata
# Initializes the metadata record for a customer-managed encryption key stored in AWS or GCP, linking it to the organization.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def post_postcmekmetadata [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "POST" $"/v4/organizations/($organizationId)/cmek"  $query_params  $header_params  $body
}

# List Key Metadata
# Retrieves detailed metadata for all customer-managed encryption keys associated with the organization.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Organization Member
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_getkeymetadatalist [
 tool_args 
] {
  mut header_params = []

  mut query_params = []
  if ( ( $tool_args | get -i page ) != null ) {
    $query_params = $query_params | append  { page : ( $tool_args | get page ) } 
  }
  if ( ( $tool_args | get -i perPage ) != null ) {
    $query_params = $query_params | append  { perPage : ( $tool_args | get perPage ) } 
  }
  if ( ( $tool_args | get -i sortBy ) != null ) {
    $query_params = $query_params | append  { sortBy : ( $tool_args | get sortBy ) } 
  }
  if ( ( $tool_args | get -i sortDirection ) != null ) {
    $query_params = $query_params | append  { sortDirection : ( $tool_args | get sortDirection ) } 
  }
  let  organizationId =  ( $tool_args | get organizationId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/cmek"  $query_params  $header_params  null
}

# List Key Rotation History
# Retrieves the full history of rotations for a specific customer-managed encryption key within the organization.
# In order to access this endpoint, the provided API key must have at least one of the following roles:
#  - Organization Owner
#  - Organization Member
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_listcmekhistory [
 tool_args 
] {
  mut header_params = []

  mut query_params = []
  if ( ( $tool_args | get -i page ) != null ) {
    $query_params = $query_params | append  { page : ( $tool_args | get page ) } 
  }
  if ( ( $tool_args | get -i perPage ) != null ) {
    $query_params = $query_params | append  { perPage : ( $tool_args | get perPage ) } 
  }
  if ( ( $tool_args | get -i sortBy ) != null ) {
    $query_params = $query_params | append  { sortBy : ( $tool_args | get sortBy ) } 
  }
  if ( ( $tool_args | get -i sortDirection ) != null ) {
    $query_params = $query_params | append  { sortDirection : ( $tool_args | get sortDirection ) } 
  }
  let  organizationId =  ( $tool_args | get organizationId ) 
   let  cmekId =  ( $tool_args | get cmekId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/cmek/($cmekId)/history"  $query_params  $header_params  null
}

# Get Key Metadata
# Retrieves the full metadata details for a specific customer-managed encryption key within the organization.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
#  - Organization Owner
#  - Organization Member
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_getkeymetadata [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  cmekId =  ( $tool_args | get cmekId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/cmek/($cmekId)"  $query_params  $header_params  null
}

# Rotate Key
# Initiates the process to rotate a customer-managed encryption key and update its associated metadata within the system.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def put_rotatecmekkey [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  cmekId =  ( $tool_args | get cmekId ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "PUT" $"/v4/organizations/($organizationId)/cmek/($cmekId)"  $query_params  $header_params  $body
}

# Delete Key Metadata
# Permanently removes the specified customer-managed encryption key's metadata from the organization's account.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def delete_deletekeymetadata [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  cmekId =  ( $tool_args | get cmekId ) 
  curl_request  "DELETE" $"/v4/organizations/($organizationId)/cmek/($cmekId)"  $query_params  $header_params  null
}

# Associate Key with Cluster
# Redeploys the cluster and encrypts the disks with the newly associated customer-managed encryption key.
# Throws an error before redeploying the cluster if the customer-managed encryption key is inaccessible.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def post_associatecmek [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  cmekId =  ( $tool_args | get cmekId ) 
  curl_request  "POST" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/cmek/($cmekId)/associate"  $query_params  $header_params  null
}

# Unassociate Key from Cluster
# Removes the customer-managed encryption key associated with the cluster, which redeploys the cluster and removes any encryption on the disks.
# This does not delete the customer-managed encryption key itself since the same key could be used across clusters.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def post_unassociatecmek [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  cmekId =  ( $tool_args | get cmekId ) 
  curl_request  "POST" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/cmek/($cmekId)/unassociate"  $query_params  $header_params  null
}

# Create User
# Invites a new user under the organization.
# 
# After making a REST API request, an invitation email is triggered and sent to the user.
# Upon receiving the invitation email, the user is required to click on a provided URL, which will redirect them to a page with a user interface (UI) where they can set their username and password.
# 
# The modification of any personal information related to a user can only be performed by the user through the UI.
# Similarly, the user can solely conduct password updates through the UI.
# 
# The "caller" possessing Organization Owner access rights retains the exclusive user creation capability.
# They hold the authority to assign roles at the organization and project levels.
# 
# At present, our support is limited to the resourceType of "project" exclusively.
# 
# In order to access this endpoint, the provided API key must have the following role:
# - Organization Owner
# 
# To learn more, see [Organization Roles](https://docs.couchbase.com/cloud/organizations/organization-user-roles.html).
# 
def post_postuser [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "POST" $"/v4/organizations/($organizationId)/users"  $query_params  $header_params  $body
}

# List Users
# Lists all the users in the organization and filter on the basis of projectId.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Organization Member
# - Project Creator
# 
# The results are always limited by the role and scope of the caller's privileges.
# 
# When retrieving a list of users through a GET request, if a user holds the organization owner role, the response will exclude project-level permissions for those users. This is because organization owners have full access to all resources within the organization, making project-level permissions irrelevant for them.
# 
# To learn more about the roles, see [Organization Roles](https://docs.couchbase.com/cloud/organizations/organization-user-roles.html) and [Project Roles](https://docs.couchbase.com/cloud/projects/project-roles.html).
# 
def get_listusers [
 tool_args 
] {
  mut header_params = []

  mut query_params = []
  if ( ( $tool_args | get -i page ) != null ) {
    $query_params = $query_params | append  { page : ( $tool_args | get page ) } 
  }
  if ( ( $tool_args | get -i perPage ) != null ) {
    $query_params = $query_params | append  { perPage : ( $tool_args | get perPage ) } 
  }
  if ( ( $tool_args | get -i sortBy ) != null ) {
    $query_params = $query_params | append  { sortBy : ( $tool_args | get sortBy ) } 
  }
  if ( ( $tool_args | get -i sortDirection ) != null ) {
    $query_params = $query_params | append  { sortDirection : ( $tool_args | get sortDirection ) } 
  }
  if ( ( $tool_args | get -i projectId ) != null ) {
    $query_params = $query_params | append  { projectId : ( $tool_args | get projectId ) } 
  }
  let  organizationId =  ( $tool_args | get organizationId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/users"  $query_params  $header_params  null
}

# Get User
# Fetches the details of the given user.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Organization Member
# - Project Creator
# 
# The results are always limited by the role and scope of the caller's privileges.
# 
# When performing a GET request for a user with an organization owner role, the response will exclude project-level permissions for that user. This is because organization owners have access to all resources at the organization level, rendering project-level permissions unnecessary for them.
# 
# To learn more about the roles, see [Organization Roles](https://docs.couchbase.com/cloud/organizations/organization-user-roles.html) and [Project Roles](https://docs.couchbase.com/cloud/projects/project-roles.html).
# 
def get_getuser [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  userId =  ( $tool_args | get userId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/users/($userId)"  $query_params  $header_params  null
}

# Update User
# Updates organizationRole and resources of the user.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# 
# An Organization Owner API key can be utilized to update organizational-level roles and project-level roles for all projects within the organization.
# 
# The Project Owner API key allows for updating project-level roles, solely within the projects where the API key holds the Project Owner role.
# 
# The modification of any personal information related to a user, such as password updates, can only be performed by the respective user through the user interface (UI).
# 
# The results are always limited by the role and scope of the caller's privileges.
# To learn more about the roles, see [Organization Roles](https://docs.couchbase.com/cloud/organizations/organization-user-roles.html) and [Project Roles](https://docs.couchbase.com/cloud/projects/project-roles.html).
# 
def patch_patchuser [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  userId =  ( $tool_args | get userId ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "PATCH" $"/v4/organizations/($organizationId)/users/($userId)"  $query_params  $header_params  $body
}

# Delete User
# Removes user from the organization.
# 
# In order to access this endpoint, the provided API key must have the following role:
# - Organization Owner
# 
# To learn more about the roles, see [Organization Roles](https://docs.couchbase.com/cloud/organizations/organization-user-roles.html).
# 
def delete_deleteuser [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  userId =  ( $tool_args | get userId ) 
  curl_request  "DELETE" $"/v4/organizations/($organizationId)/users/($userId)"  $query_params  $header_params  null
}

# Create Allowed CIDR
# Adds a trusted CIDR to a cluster's list of allowed CIDRs.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
# Note that updating this resource is not supported; you must delete and recreate allowed CIDRs instead. As a result, ETags are also not supported for this resource.
# 
def post_postallowedcidrs [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "POST" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/allowedcidrs"  $query_params  $header_params  $body
}

# List Allowed CIDRs
# Lists all of the allowed CIDRs for a given cluster.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# - Project Viewer
# - Database Data Reader/Writer
# - Database Data Reader
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_listallowedcidrs [
 tool_args 
] {
  mut header_params = []

  mut query_params = []
  if ( ( $tool_args | get -i page ) != null ) {
    $query_params = $query_params | append  { page : ( $tool_args | get page ) } 
  }
  if ( ( $tool_args | get -i perPage ) != null ) {
    $query_params = $query_params | append  { perPage : ( $tool_args | get perPage ) } 
  }
  if ( ( $tool_args | get -i sortBy ) != null ) {
    $query_params = $query_params | append  { sortBy : ( $tool_args | get sortBy ) } 
  }
  if ( ( $tool_args | get -i sortDirection ) != null ) {
    $query_params = $query_params | append  { sortDirection : ( $tool_args | get sortDirection ) } 
  }
  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/allowedcidrs"  $query_params  $header_params  null
}

# get allowed CIDR
# Fetches the details for the specified allowed CIDR.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# - Project Viewer
# - Database Data Reader/Writer
# - Database Data Reader
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_getallowedcidrbyid [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  allowedCidrId =  ( $tool_args | get allowedCidrId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/allowedcidrs/($allowedCidrId)"  $query_params  $header_params  null
}

# Delete Allowed CIDR
# Deletes the existing allowed CIDR.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def delete_deleteallowedcidrbyid [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  allowedCidrId =  ( $tool_args | get allowedCidrId ) 
  curl_request  "DELETE" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/allowedcidrs/($allowedCidrId)"  $query_params  $header_params  null
}

# List Database Credentials
# Lists all the database credential information under a cluster.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
#  - Organization Owner
#  - Project Owner
#  - Project Viewer
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_listdatabasecredentials [
 tool_args 
] {
  mut header_params = []

  mut query_params = []
  if ( ( $tool_args | get -i page ) != null ) {
    $query_params = $query_params | append  { page : ( $tool_args | get page ) } 
  }
  if ( ( $tool_args | get -i perPage ) != null ) {
    $query_params = $query_params | append  { perPage : ( $tool_args | get perPage ) } 
  }
  if ( ( $tool_args | get -i sortBy ) != null ) {
    $query_params = $query_params | append  { sortBy : ( $tool_args | get sortBy ) } 
  }
  if ( ( $tool_args | get -i sortDirection ) != null ) {
    $query_params = $query_params | append  { sortDirection : ( $tool_args | get sortDirection ) } 
  }
  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/users"  $query_params  $header_params  null
}

# Create Database Credentials
# Creates a new database credential under a cluster.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# 
# Valid fields to sort the results are: "id", "name".
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def post_postdatabasecredential [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "POST" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/users"  $query_params  $header_params  $body
}

# Create Free Tier App Service
# Creates a free tier App Service. This is a 1 node cluster which can only be linked to a free tier cluster.
# 
# The following features are not available for free tier clusters:
#   - audit logging 
#   - turn App Service off/on
# 
# Free tier App Service can only be turned off/on when the linked free tier cluster is turned off/on.
# 
# Only name a description are configurable.
# 
# In order to access this endpoint, the provided API key must have at least one of the roles referenced below:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def post_createfreetierappservice [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "POST" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/appservices/freeTier"  $query_params  $header_params  $body
}

# Create App Service
# Creates a new App Service.
# 
# In order to access this endpoint, the provided API key must have at least one of the roles referenced below:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def post_postappservice [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "POST" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/appservices"  $query_params  $header_params  $body
}

# List AppServices
# Lists all the clusters under the organization.
# 
# In order to access this endpoint, the provided API key must have at least one of the roles referenced below:
# - Organization Owner
# - Project Owner
# - Project Manager
# - Project Viewer
# - Database Data Reader/Writer
# - Database Data Reader
# 
# Returned set of clusters is reduced to what the caller has access to view.
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_listappservices [
 tool_args 
] {
  mut header_params = []

  mut query_params = []
  if ( ( $tool_args | get -i page ) != null ) {
    $query_params = $query_params | append  { page : ( $tool_args | get page ) } 
  }
  if ( ( $tool_args | get -i perPage ) != null ) {
    $query_params = $query_params | append  { perPage : ( $tool_args | get perPage ) } 
  }
  if ( ( $tool_args | get -i sortBy ) != null ) {
    $query_params = $query_params | append  { sortBy : ( $tool_args | get sortBy ) } 
  }
  if ( ( $tool_args | get -i sortDirection ) != null ) {
    $query_params = $query_params | append  { sortDirection : ( $tool_args | get sortDirection ) } 
  }
  if ( ( $tool_args | get -i projectId ) != null ) {
    $query_params = $query_params | append  { projectId : ( $tool_args | get projectId ) } 
  }
  let  organizationId =  ( $tool_args | get organizationId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/appservices"  $query_params  $header_params  null
}

# Get Free Tier App Service
# Fetches the details of the free tier App Service.
# 
# While only name and description are configurable, other read only fields will be displayed.
# 
# In order to access this endpoint, the provided API key must have at least one of the roles referenced below:
#  - Organization Owner
#  - Project Owner
#  - Project Manager
#  - Project Viewer
#  - Database Data Reader/Writer
#  - Database Data Reader
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_getfreetierappservice [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  appServiceId =  ( $tool_args | get appServiceId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/appservices/freeTier/($appServiceId)"  $query_params  $header_params  null
}

# Update Free Tier App Service
# Updates an existing free tier App Service. Only name and description are configurable.
# 
# In order to access this endpoint, the provided API key must have at least one of the roles referenced below:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def put_updatefreetierappservice [
 tool_args 
] {
  mut header_params = []
  if ( ( $tool_args | get -i If-Match ) != null ) {
    $header_params = $header_params | append  { If-Match : ( $tool_args | get If-Match ) } 
  }
  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  appServiceId =  ( $tool_args | get appServiceId ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "PUT" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/appservices/freeTier/($appServiceId)"  $query_params  $header_params  $body
}

# Delete Free Tier App Service
# Deletes an existing free tier App Service.
# 
# In order to access this endpoint, the provided API key must have at least one of the roles referenced below:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def delete_deletefreetierappservice [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  appServiceId =  ( $tool_args | get appServiceId ) 
  curl_request  "DELETE" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/appservices/freeTier/($appServiceId)"  $query_params  $header_params  null
}

# Get App Service
# Fetches the details of the given App Service.
# 
# In order to access this endpoint, the provided API key must have at least one of the roles referenced below:
#  - Organization Owner
#  - Project Owner
#  - Project Manager
#  - Project Viewer
#  - Database Data Reader/Writer
#  - Database Data Reader
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_getappservice [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  appServiceId =  ( $tool_args | get appServiceId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/appservices/($appServiceId)"  $query_params  $header_params  null
}

# Update App Service
# Updates an existing App Service.
# 
# In order to access this endpoint, the provided API key must have at least one of the roles referenced below:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def put_putappservice [
 tool_args 
] {
  mut header_params = []
  if ( ( $tool_args | get -i If-Match ) != null ) {
    $header_params = $header_params | append  { If-Match : ( $tool_args | get If-Match ) } 
  }
  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  appServiceId =  ( $tool_args | get appServiceId ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "PUT" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/appservices/($appServiceId)"  $query_params  $header_params  $body
}

# Delete App Service
# Deletes an existing App Service.
# 
# In order to access this endpoint, the provided API key must have at least one of the roles referenced below:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def delete_deleteappservice [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  appServiceId =  ( $tool_args | get appServiceId ) 
  curl_request  "DELETE" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/appservices/($appServiceId)"  $query_params  $header_params  null
}

# Turn On App Service
# Turn App Service on. Free tier App Service can only be turned on when the linked free tier cluster is turned on.
# 
# In order to access this endpoint, the provided API key must have at least one of the roles referenced below:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def post_appserviceon [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  appServiceId =  ( $tool_args | get appServiceId ) 
  curl_request  "POST" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/appservices/($appServiceId)/activationState"  $query_params  $header_params  null
}

# Turn Off App Service
# Turn App Service off.
# 
# Turn off an App Service to temporarily deactivate it and reduce its consumption of compute resources.
# The App Service itself and its related infrastructure will be removed once turned off.
# 
# Free tier App Service can only be turned off when the linked free tier cluster is turned off.
# 
# In order to access this endpoint, the provided API key must have at least one of the roles referenced below:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def delete_appserviceoff [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  appServiceId =  ( $tool_args | get appServiceId ) 
  curl_request  "DELETE" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/appservices/($appServiceId)/activationState"  $query_params  $header_params  null
}

# Delete App Service Allowed CIDR
# Deletes an Allowed CIDR by ID on the specified App Service.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def delete_deleteappserviceallowedcidr [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  appServiceId =  ( $tool_args | get appServiceId ) 
   let  allowedCidrId =  ( $tool_args | get allowedCidrId ) 
  curl_request  "DELETE" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/appservices/($appServiceId)/allowedcidrs/($allowedCidrId)"  $query_params  $header_params  null
}

# List Allowed CIDRs for an App Service
# Lists the Allowed CIDRs for the specified App Service.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_listappserviceallowedcidrs [
 tool_args 
] {
  mut header_params = []

  mut query_params = []
  if ( ( $tool_args | get -i page ) != null ) {
    $query_params = $query_params | append  { page : ( $tool_args | get page ) } 
  }
  if ( ( $tool_args | get -i perPage ) != null ) {
    $query_params = $query_params | append  { perPage : ( $tool_args | get perPage ) } 
  }
  if ( ( $tool_args | get -i sortBy ) != null ) {
    $query_params = $query_params | append  { sortBy : ( $tool_args | get sortBy ) } 
  }
  if ( ( $tool_args | get -i sortDirection ) != null ) {
    $query_params = $query_params | append  { sortDirection : ( $tool_args | get sortDirection ) } 
  }
  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  appServiceId =  ( $tool_args | get appServiceId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/appservices/($appServiceId)/allowedcidrs"  $query_params  $header_params  null
}

# Create Allowed CIDR
# Adds a trusted CIDR to the specified App Service's list of allowed CIDRs.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def post_postappserviceallowedcidr [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  appServiceId =  ( $tool_args | get appServiceId ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "POST" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/appservices/($appServiceId)/allowedcidrs"  $query_params  $header_params  $body
}

# Create App Service Admin User
# Creates an Admin User on the specified App Service.
# The user can either be granted access to all App Endpoints or to specific App Endpoints by listing them in the ```endpoints``` field.
# 
# Currently, the user will be granted admin access to all App Endpoints in a bucket (that is currently associated with the App Endpoint(s) specified in the endpoints field), including ones that are created in future.
# An option to grant access to specific App Endpoints in a bucket will be available in the future.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def post_addappserviceadminuser [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  appServiceId =  ( $tool_args | get appServiceId ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "POST" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/appservices/($appServiceId)/adminUsers"  $query_params  $header_params  $body
}

# List App Service Admin Users
# List the admin users for the specified App Service.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# - Project Viewer
# - Database Data Reader/Writer
# - Database Data Reader
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_listappserviceadminusers [
 tool_args 
] {
  mut header_params = []

  mut query_params = []
  if ( ( $tool_args | get -i page ) != null ) {
    $query_params = $query_params | append  { page : ( $tool_args | get page ) } 
  }
  if ( ( $tool_args | get -i perPage ) != null ) {
    $query_params = $query_params | append  { perPage : ( $tool_args | get perPage ) } 
  }
  if ( ( $tool_args | get -i sortDirection ) != null ) {
    $query_params = $query_params | append  { sortDirection : ( $tool_args | get sortDirection ) } 
  }
  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  appServiceId =  ( $tool_args | get appServiceId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/appservices/($appServiceId)/adminUsers"  $query_params  $header_params  null
}

# Update App Service Admin User
# Updates the Admin User's access to App Endpoints on the specified App Service.
# The update operation can either grant access to all App Endpoints or to specific App Endpoints by listing them in the ```endpoints``` field.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def put_updateappserviceadminuser [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  appServiceId =  ( $tool_args | get appServiceId ) 
   let  userId =  ( $tool_args | get userId ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "PUT" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/appservices/($appServiceId)/adminUsers/($userId)"  $query_params  $header_params  $body
}

# Delete App Service Admin User
# Deletes the Admin User.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def delete_deleteappserviceadminuser [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  appServiceId =  ( $tool_args | get appServiceId ) 
   let  userId =  ( $tool_args | get userId ) 
  curl_request  "DELETE" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/appservices/($appServiceId)/adminUsers/($userId)"  $query_params  $header_params  null
}

# Get App Service Admin User
# Fetches the Admin User.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_getappserviceadminuser [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  appServiceId =  ( $tool_args | get appServiceId ) 
   let  userId =  ( $tool_args | get userId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/appservices/($appServiceId)/adminUsers/($userId)"  $query_params  $header_params  null
}

# Enable or Disable App Service Audit Logging
# Enable or disable Audit Logging for an App Service.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
#  - Organization Owner
#  - Project Owner
#  - Project Manager
# 
#  To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def put_putappserviceauditlogstate [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  appServiceId =  ( $tool_args | get appServiceId ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "PUT" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/appservices/($appServiceId)/auditLog"  $query_params  $header_params  $body
}

# Get App Service Audit Log State
# Retrieves the audit logging state for a specific App Service.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
#  - Organization Owner
#  - Project Owner
#  - Project Manager
#  - Project Viewer
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_getappserviceauditlogstate [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  appServiceId =  ( $tool_args | get appServiceId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/appservices/($appServiceId)/auditLog"  $query_params  $header_params  null
}

# Get Public Certificate for App Service
# The public certificate is a trusted Certificate Authority (CA) signed certificate.
# You can copy or download the endpoint’s SSL public certificate to bundle into your mobile application.
# Pinning your certificate to your App is not recommended as it can increase maintenance overhead and downtime risks.
# For more information, see [here](https://docs.couchbase.com/cloud/app-services/connect/connect-apps-to-endpoint.html#setting-up-the-connection).
# 
# In order to access this endpoint, the provided API key must have at least one of the roles referenced below:
#  - Organization Owner
#  - Project Owner
#  - Project Manager
#  - Project Viewer
#  - Database Data Reader/Writer
#  - Database Data Reader
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_getappservicecertificate [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  appServiceId =  ( $tool_args | get appServiceId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/appservices/($appServiceId)/certificates"  $query_params  $header_params  null
}

# List App Endpoints
# Lists all the App Endpoints under a specific App Service along with their associated configurations such as Access Control function, Import Filter or user defined xattr key.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# - Project Viewer
# - Database Data Reader/Writer
# - Database Data Reader
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_listappendpoints [
 tool_args 
] {
  mut header_params = []

  mut query_params = []
  if ( ( $tool_args | get -i page ) != null ) {
    $query_params = $query_params | append  { page : ( $tool_args | get page ) } 
  }
  if ( ( $tool_args | get -i perPage ) != null ) {
    $query_params = $query_params | append  { perPage : ( $tool_args | get perPage ) } 
  }
  if ( ( $tool_args | get -i sortDirection ) != null ) {
    $query_params = $query_params | append  { sortDirection : ( $tool_args | get sortDirection ) } 
  }
  if ( ( $tool_args | get -i sortBy ) != null ) {
    $query_params = $query_params | append  { sortBy : ( $tool_args | get sortBy ) } 
  }
  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  appServiceId =  ( $tool_args | get appServiceId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/appservices/($appServiceId)/appEndpoints"  $query_params  $header_params  null
}

# Create App Endpoint
# Creates an App Endpoint within an App Service with specific configurations such as collection level Access Control function and Import Filter.
# If the scopes property is not included in the request body, the default scope and collection will be used.
# The first OpenID Connect provider given will be set as the default provider for the App Endpoint. To change the default, please use the Change App Endpoint OIDC Default Provider endpoint.
# 
# In order to access this endpoint, the provided API key must have at least one of the roles referenced below:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def post_postappendpoint [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  appServiceId =  ( $tool_args | get appServiceId ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "POST" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/appservices/($appServiceId)/appEndpoints"  $query_params  $header_params  $body
}

# Get App Endpoint
# Fetches the details of the given App Endpoint, including operational and resync states and various configurations such as Access Control function and Import Filter.
# 
# In order to access this endpoint, the provided API key must have at least one of the roles referenced below:
#  - Organization Owner
#  - Project Owner
#  - Project Manager
#  - Project Viewer
#  - Database Data Reader/Writer
#  - Database Data Reader
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_getappendpoint [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  appServiceId =  ( $tool_args | get appServiceId ) 
   let  appEndpointName =  ( $tool_args | get appEndpointName ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/appservices/($appServiceId)/appEndpoints/($appEndpointName)"  $query_params  $header_params  null
}

# Update App Endpoint
# Replaces a specified App Endpoint’s configurations such as Access Control function, Import Filter, Delta Sync, or user defined xattr key.
# The first OpenID Connect provider given will be set as the default provider for the App Endpoint. To change the default, please use the Change App Endpoint OIDC Default Provider endpoint.
# All fields are required, the App Endpoint and bucket names cannot be changed.
# 
# In order to access this endpoint, the provided API key must have at least one of the roles referenced below:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def put_putappendpoint [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  appServiceId =  ( $tool_args | get appServiceId ) 
   let  appEndpointName =  ( $tool_args | get appEndpointName ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "PUT" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/appservices/($appServiceId)/appEndpoints/($appEndpointName)"  $query_params  $header_params  $body
}

# Delete App Endpoint
# Deletes an existing App Endpoint given its name.
# 
# In order to access this endpoint, the provided API key must have at least one of the roles referenced below:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def delete_deleteappendpoint [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  appServiceId =  ( $tool_args | get appServiceId ) 
   let  appEndpointName =  ( $tool_args | get appEndpointName ) 
  curl_request  "DELETE" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/appservices/($appServiceId)/appEndpoints/($appEndpointName)"  $query_params  $header_params  null
}

# List App Endpoint Collections
# Lists all the collections under a specific App Endpoint along with their associated configurations such as Access Control function, Import Filter or user defined xattr key.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# - Project Viewer
# - Database Data Reader/Writer
# - Database Data Reader
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_listappendpointcollections [
 tool_args 
] {
  mut header_params = []

  mut query_params = []
  if ( ( $tool_args | get -i page ) != null ) {
    $query_params = $query_params | append  { page : ( $tool_args | get page ) } 
  }
  if ( ( $tool_args | get -i perPage ) != null ) {
    $query_params = $query_params | append  { perPage : ( $tool_args | get perPage ) } 
  }
  if ( ( $tool_args | get -i sortDirection ) != null ) {
    $query_params = $query_params | append  { sortDirection : ( $tool_args | get sortDirection ) } 
  }
  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  appServiceId =  ( $tool_args | get appServiceId ) 
   let  appEndpointName =  ( $tool_args | get appEndpointName ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/appservices/($appServiceId)/appEndpoints/($appEndpointName)/collections"  $query_params  $header_params  null
}

# Resume or Bring an App Endpoint online
# Brings an App Endpoint online to close and reopen the connection to the backing Cluster bucket,
# re-establish access from the Public REST API and accept all incoming Admin API requests.
# 
# In order to access this endpoint, the provided API key must have at least one of the roles referenced below:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def post_postappendpointactivationstatus [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  appServiceId =  ( $tool_args | get appServiceId ) 
   let  appEndpointName =  ( $tool_args | get appEndpointName ) 
  curl_request  "POST" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/appservices/($appServiceId)/appEndpoints/($appEndpointName)/activationStatus"  $query_params  $header_params  null
}

# Pause or Take an App Endpoint offline
# Take the database offline to run resync or to make changes without disrupting current App Endpoint operations.
# Clients currently connected to the App Endpoint will not be able to sync data with the Cluster while the App Endpoint is paused.
# This will not take the backing Cluster bucket offline.
# Pausing an App Endpoint that is in the progress of coming online will pause the App Endpoint after it comes online.
# 
# In order to access this endpoint, the provided API key must have at least one of the roles referenced below:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def delete_deleteappendpointactivationstatus [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  appServiceId =  ( $tool_args | get appServiceId ) 
   let  appEndpointName =  ( $tool_args | get appEndpointName ) 
  curl_request  "DELETE" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/appservices/($appServiceId)/appEndpoints/($appEndpointName)/activationStatus"  $query_params  $header_params  null
}

# Get the App Endpoint Cross-Origin Resource Sharing (CORS) Configuration.
# Fetch the App Endpoint Cross-Origin Resource Sharing (CORS) Configuration.
# CORS is disabled by default. For more information
# See [Cross-Origin Resource Sharing (CORS) on App Endpoints.](https://docs.couchbase.com/cloud/app-services/deployment/cors-configuration-for-app-services.html)
# 
# In order to access this endpoint, the provided API key must have at least one of the roles referenced below:
#  - Organization Owner
#  - Project Owner
#  - Project Manager
#  - Project Viewer
#  - Database Data Reader/Writer
#  - Database Data Reader
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_getappendpointcors [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  appServiceId =  ( $tool_args | get appServiceId ) 
   let  appEndpointName =  ( $tool_args | get appEndpointName ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/appservices/($appServiceId)/appEndpoints/($appEndpointName)/cors"  $query_params  $header_params  null
}

# Upsert the App Endpoint Cross-Origin Resource Sharing (CORS) Configuration.
# Upsert the App Endpoint Cross-Origin Resource Sharing (CORS) Configuration.
# CORS is disabled by default. For more information
# See [Cross-Origin Resource Sharing (CORS) on App Endpoints.](https://docs.couchbase.com/cloud/app-services/deployment/cors-configuration-for-app-services.html)
# 
# In order to access this endpoint, the provided API key must have at least one of the roles referenced below:
#  - Organization Owner
#  - Project Owner
#  - Project Manager
#  - Project Viewer
#  - Database Data Reader/Writer
#  - Database Data Reader
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def put_putappendpointcors [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  appServiceId =  ( $tool_args | get appServiceId ) 
   let  appEndpointName =  ( $tool_args | get appEndpointName ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "PUT" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/appservices/($appServiceId)/appEndpoints/($appEndpointName)/cors"  $query_params  $header_params  $body
}

# List App Endpoint Admin Users
# Lists the Admin Users that have access to the specified App Endpoint.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# - Project Viewer
# - Database Data Reader/Writer
# - Database Data Reader
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_listappendpointadminusers [
 tool_args 
] {
  mut header_params = []

  mut query_params = []
  if ( ( $tool_args | get -i page ) != null ) {
    $query_params = $query_params | append  { page : ( $tool_args | get page ) } 
  }
  if ( ( $tool_args | get -i perPage ) != null ) {
    $query_params = $query_params | append  { perPage : ( $tool_args | get perPage ) } 
  }
  if ( ( $tool_args | get -i sortDirection ) != null ) {
    $query_params = $query_params | append  { sortDirection : ( $tool_args | get sortDirection ) } 
  }
  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  appServiceId =  ( $tool_args | get appServiceId ) 
   let  appEndpointName =  ( $tool_args | get appEndpointName ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/appservices/($appServiceId)/appEndpoints/($appEndpointName)/adminUsers"  $query_params  $header_params  null
}

# List App Endpoint Audit Log Event IDs
# Retrieves all audit log event ids, their descriptions and enabled status for an App Endpoint.
# The list of filterable event IDs can be specified while configuring audit logging for the App Service.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# - Project Viewer
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_getappserviceauditlogevents [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  appServiceId =  ( $tool_args | get appServiceId ) 
   let  appEndpointName =  ( $tool_args | get appEndpointName ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/appservices/($appServiceId)/appEndpoints/($appEndpointName)/auditLogEvents"  $query_params  $header_params  null
}

# Update App Endpoint Audit Logging Config
# Updates the audit logging configuration for a specific App Endpoint. Operations performed by disabled users and roles are excluded from audit logs.
# See a list of event IDs by calling /auditLogEvents, add event IDs to the enabledEventIds field to enable audit logging for those events.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
#  - Organization Owner
#  - Project Owner
#  - Project Manager
# 
#  To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def put_putappendpointauditlogconfig [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  appServiceId =  ( $tool_args | get appServiceId ) 
   let  appEndpointName =  ( $tool_args | get appEndpointName ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "PUT" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/appservices/($appServiceId)/appEndpoints/($appEndpointName)/auditLog"  $query_params  $header_params  $body
}

# Get App Endpoint Audit Logging Config
# Retrieves the audit logging configuration for a specific App Endpoint.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# - Project Viewer
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_getappendpointauditlogconfig [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  appServiceId =  ( $tool_args | get appServiceId ) 
   let  appEndpointName =  ( $tool_args | get appEndpointName ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/appservices/($appServiceId)/appEndpoints/($appEndpointName)/auditLog"  $query_params  $header_params  null
}

# Get Access Control and Validation function
# Retrieves the Access Control and Validation function for the given keyspace.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# - Project Viewer
# - Database Data Reader/Writer
# - Database Data Reader
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_getaccessfunction [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  appServiceId =  ( $tool_args | get appServiceId ) 
   let  appEndpointKeyspace =  ( $tool_args | get appEndpointKeyspace ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/appservices/($appServiceId)/appEndpoints/($appEndpointKeyspace)/accessControlFunction"  $query_params  $header_params  null
}

# Upsert custom Access Control and Validation function
# Used to upsert a custom Access Control and Validation function for the given keyspace.
# This is a Javascript function specified at a keyspace, where a user’s read/write access is defined for documents in that particular keyspace.
# Every document mutation is processed by this function. If an Access Control function is not explicitly defined, a default is applied.
# [Read more.](https://docs.couchbase.com/cloud/app-services/deployment/access-control-data-validation.html?)
# 
# In order to access this endpoint, the provided API key must have at least one of the roles referenced below:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def put_putaccessfunction [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  appServiceId =  ( $tool_args | get appServiceId ) 
   let  appEndpointKeyspace =  ( $tool_args | get appEndpointKeyspace ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "PUT" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/appservices/($appServiceId)/appEndpoints/($appEndpointKeyspace)/accessControlFunction"  $query_params  $header_params  $body
}

# Delete Access Control and Validation function
# Deletes the Access Control and Validation function for the given keyspace.
# 
# In order to access this endpoint, the provided API key must have at least one of the roles referenced below:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def delete_deleteaccessfunction [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  appServiceId =  ( $tool_args | get appServiceId ) 
   let  appEndpointKeyspace =  ( $tool_args | get appEndpointKeyspace ) 
  curl_request  "DELETE" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/appservices/($appServiceId)/appEndpoints/($appEndpointKeyspace)/accessControlFunction"  $query_params  $header_params  null
}

# Get Import Filter
# Retrieves the Import Filter for the given keyspace.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# - Project Viewer
# - Database Data Reader/Writer
# - Database Data Reader
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_getimportfilter [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  appServiceId =  ( $tool_args | get appServiceId ) 
   let  appEndpointKeyspace =  ( $tool_args | get appEndpointKeyspace ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/appservices/($appServiceId)/appEndpoints/($appEndpointKeyspace)/importFilter"  $query_params  $header_params  null
}

# Upsert Import Filter
# Upserts the Import Filter for the given keyspace. By default, there is no import filter and all documents are imported.
# Import Filters identify the subset of documents eligible to be replicated by App services based on user-defined requirements.
# This subset is applied to all future mutations.
# Once the document has been imported and processed by the App Endpoint, changing the Import Filter will not remove it,
# even if the updated import filters would prevent newer mutations or iterations of the document from getting imported.
# [Read more.](https://docs.couchbase.com/cloud/app-services/deployment/import-filters.html)
# 
# In order to access this endpoint, the provided API key must have at least one of the roles referenced below:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def put_putimportfilter [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  appServiceId =  ( $tool_args | get appServiceId ) 
   let  appEndpointKeyspace =  ( $tool_args | get appEndpointKeyspace ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "PUT" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/appservices/($appServiceId)/appEndpoints/($appEndpointKeyspace)/importFilter"  $query_params  $header_params  $body
}

# Delete Import Filter
# Deletes the Import Filter for the given keyspace.
# 
# In order to access this endpoint, the provided API key must have at least one of the roles referenced below:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def delete_deleteimportfilter [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  appServiceId =  ( $tool_args | get appServiceId ) 
   let  appEndpointKeyspace =  ( $tool_args | get appEndpointKeyspace ) 
  curl_request  "DELETE" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/appservices/($appServiceId)/appEndpoints/($appEndpointKeyspace)/importFilter"  $query_params  $header_params  null
}

# Create App Endpoint OpenID Connect (OIDC) Provider
# Creates an OIDC provider for the specified App Endpoint.
# The first OIDC provider will automatically be set as the default OIDC provider.
# All client requests will use the default OIDC provider, unless the OIDC provider for the request is explicitly specified on authentication.
# See more [here](https://docs.couchbase.com/cloud/app-services/user-management/set-up-authentication-provider.html#oidc-authorization-step-by-step).
# 
# 
# In order to access this endpoint, the provided API key must have at least one of the roles referenced below:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def post_createappendpointoidcprovider [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  appServiceId =  ( $tool_args | get appServiceId ) 
   let  appEndpointName =  ( $tool_args | get appEndpointName ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "POST" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/appservices/($appServiceId)/appEndpoints/($appEndpointName)/oidcProviders"  $query_params  $header_params  $body
}

# List App Endpoint OpenID Connect (OIDC) Providers
# List OpenID Connect (OIDC) Providers configured on an App Endpoint.
# 
# In order to access this endpoint, the provided API key must have at least one of the roles referenced below:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_listappendpointoidcproviders [
 tool_args 
] {
  mut header_params = []

  mut query_params = []
  if ( ( $tool_args | get -i page ) != null ) {
    $query_params = $query_params | append  { page : ( $tool_args | get page ) } 
  }
  if ( ( $tool_args | get -i perPage ) != null ) {
    $query_params = $query_params | append  { perPage : ( $tool_args | get perPage ) } 
  }
  if ( ( $tool_args | get -i sortDirection ) != null ) {
    $query_params = $query_params | append  { sortDirection : ( $tool_args | get sortDirection ) } 
  }
  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  appServiceId =  ( $tool_args | get appServiceId ) 
   let  appEndpointName =  ( $tool_args | get appEndpointName ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/appservices/($appServiceId)/appEndpoints/($appEndpointName)/oidcProviders"  $query_params  $header_params  null
}

# Get App Endpoint OpenID Connect (OIDC) Provider
# Fetches an OIDC provider by ID for the specified App Endpoint.
# 
# In order to access this endpoint, the provided API key must have at least one of the roles referenced below:
#  - Organization Owner
#  - Project Owner
#  - Project Manager
#  - Project Viewer
#  - Database Data Reader/Writer
#  - Database Data Reader
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_getappendpointoidcprovider [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  appServiceId =  ( $tool_args | get appServiceId ) 
   let  appEndpointName =  ( $tool_args | get appEndpointName ) 
   let  OIDCProviderId =  ( $tool_args | get OIDCProviderId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/appservices/($appServiceId)/appEndpoints/($appEndpointName)/oidcProviders/($OIDCProviderId)"  $query_params  $header_params  null
}

# Update App Endpoint OpenID Connect (OIDC) Provider
# Updates an OIDC provider for the specified App Endpoint.
# 
# In order to access this endpoint, the provided API key must have at least one of the roles referenced below:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def put_updateappendpointoidcprovider [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  appServiceId =  ( $tool_args | get appServiceId ) 
   let  appEndpointName =  ( $tool_args | get appEndpointName ) 
   let  OIDCProviderId =  ( $tool_args | get OIDCProviderId ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "PUT" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/appservices/($appServiceId)/appEndpoints/($appEndpointName)/oidcProviders/($OIDCProviderId)"  $query_params  $header_params  $body
}

# Delete App Endpoint OpenID Connect (OIDC) Provider
# Deletes an OIDC provider for the specified App Endpoint. Deleting the default provider will error unless it is the only provider.
# Before deleting the default provider, you must set a new provider as default or have no other providers.
# 
# In order to access this endpoint, the provided API key must have at least one of the roles referenced below:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def delete_deleteappendpointoidcprovider [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  appServiceId =  ( $tool_args | get appServiceId ) 
   let  appEndpointName =  ( $tool_args | get appEndpointName ) 
   let  OIDCProviderId =  ( $tool_args | get OIDCProviderId ) 
  curl_request  "DELETE" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/appservices/($appServiceId)/appEndpoints/($appEndpointName)/oidcProviders/($OIDCProviderId)"  $query_params  $header_params  null
}

# Update App Endpoint Default OIDC Provider
# Updates the default OIDC provider for the specified App Endpoint.
# All client requests will use the default OIDC provider, unless the OIDC provider for the request is explicitly specified.
# See more [here](https://docs.couchbase.com/cloud/app-services/user-management/set-up-authentication-provider.html#oidc-authorization-step-by-step).
# 
# In order to access this endpoint, the provided API key must have at least one of the roles referenced below:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def put_updateappendpointoidcdefaultprovider [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  appServiceId =  ( $tool_args | get appServiceId ) 
   let  appEndpointName =  ( $tool_args | get appEndpointName ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "PUT" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/appservices/($appServiceId)/appEndpoints/($appEndpointName)/oidcProviders/defaultProvider"  $query_params  $header_params  $body
}

# Get Resync Status
# Fetches the Resync status of the given App Endpoint. If no resync operation was triggered, the response will say the status is completed
# with 0 values for other properties.
# 
# In order to access this endpoint, the provided API key must have at least one of the roles referenced below:
#  - Organization Owner
#  - Project Owner
#  - Project Manager
#  - Project Viewer
#  - Database Data Reader/Writer
#  - Database Data Reader
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_getappendpointresync [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  appServiceId =  ( $tool_args | get appServiceId ) 
   let  appEndpointName =  ( $tool_args | get appEndpointName ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/appservices/($appServiceId)/appEndpoints/($appEndpointName)/resync"  $query_params  $header_params  null
}

# Start Resync
# Initialises the Resync operation for the given collections.
# By default, all collections that require resync will be resynced unless they are specified in the scopes property, in which case only
# the specified collections that require resync will be resynced.
# 
# In order to access this endpoint, the provided API key must have at least one of the roles referenced below:
#  - Organization Owner
#  - Project Owner
#  - Project Manager
#  - Project Viewer
#  - Database Data Reader/Writer
#  - Database Data Reader
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def post_postappendpointresync [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  appServiceId =  ( $tool_args | get appServiceId ) 
   let  appEndpointName =  ( $tool_args | get appEndpointName ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "POST" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/appservices/($appServiceId)/appEndpoints/($appEndpointName)/resync"  $query_params  $header_params  $body
}

# Stop Resync
# Stops the Resync operation. When stopping resync, it will be stopped for all collections being processed.
# In order to access this endpoint, the provided API key must have at least one of the roles referenced below:
#  - Organization Owner
#  - Project Owner
#  - Project Manager
#  - Project Viewer
#  - Database Data Reader/Writer
#  - Database Data Reader
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def delete_deleteappendpointresync [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  appServiceId =  ( $tool_args | get appServiceId ) 
   let  appEndpointName =  ( $tool_args | get appEndpointName ) 
  curl_request  "DELETE" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/appservices/($appServiceId)/appEndpoints/($appEndpointName)/resync"  $query_params  $header_params  null
}

# Configure App Service Audit Log Streaming
# Sets up audit log streaming for a specific App Service with filters. If streamingEnabled is true log streaming will begin.
# 
# Ensure you have provided collector credentials if you wish to begin streaming; log streaming cannot be enabled without credentials.
# Refer to schema below to see required fields for your log collection provider.
# Providers include Datadog, Sumo Logic, Grafana Loki, Elasticsearch (versions 8 and newer only) and generic HTTP.
# To start or resume streaming, set streamingEnabled to true while providing the rest of the log collector config.
# 
# To disable log streaming and remove the log streaming config including credentials, set streamingEnabled to false and leave the rest of the payload empty.
# 
# To pause log streaming, set streamingEnabled to false while providing the rest of the log collector config.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
#  - Organization Owner
#  - Project Owner
#  - Project Manager
# 
#  To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def put_putappserviceauditlogstreaming [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  appServiceId =  ( $tool_args | get appServiceId ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "PUT" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/appservices/($appServiceId)/auditLogStreaming"  $query_params  $header_params  $body
}

# Start or Resume Audit Log Streaming
# To start or resume streaming, set streamingEnabled to true. To pause log streaming, set streamingEnabled to false.
# 
# If log streaming is paused we will retain the collector credentials. To clear these use the PUT request.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
#   - Organization Owner
#   - Project Owner
#   - Project Manager
# 
#   To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def patch_patchappserviceauditlogstreaming [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  appServiceId =  ( $tool_args | get appServiceId ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "PATCH" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/appservices/($appServiceId)/auditLogStreaming"  $query_params  $header_params  $body
}

# Get App Service Audit Log Streaming State
# Retrieves the current state of audit log streaming for a specific App Service, as well as the output type and enabled App endpoints.
# 
# The audit log streaming states are:
#   - disabled
#   - disabling
#   - enabled
#   - enabling
#   - paused
#   - pausing
#   - errored
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
#  - Organization Owner
#  - Project Owner
#  - Project Manager
#  - Project Viewer
# 
#  To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_getappserviceauditlogstreaming [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  appServiceId =  ( $tool_args | get appServiceId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/appservices/($appServiceId)/auditLogStreaming"  $query_params  $header_params  null
}

# Initiate Audit Log Export
# Initiates an audit log export for a specific App Service.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
#  - Organization Owner
#  - Project Owner
#  - Project Manager
# 
#  To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def post_postappserviceauditlogexport [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  appServiceId =  ( $tool_args | get appServiceId ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "POST" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/appservices/($appServiceId)/auditLogExports"  $query_params  $header_params  $body
}

# List Audit Log Export Jobs
# Retrieves a list of all audit log export jobs for an App Service.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# - Project Viewer
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_listappserviceauditlogexports [
 tool_args 
] {
  mut header_params = []

  mut query_params = []
  if ( ( $tool_args | get -i page ) != null ) {
    $query_params = $query_params | append  { page : ( $tool_args | get page ) } 
  }
  if ( ( $tool_args | get -i perPage ) != null ) {
    $query_params = $query_params | append  { perPage : ( $tool_args | get perPage ) } 
  }
  if ( ( $tool_args | get -i sortDirection ) != null ) {
    $query_params = $query_params | append  { sortDirection : ( $tool_args | get sortDirection ) } 
  }
  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  appServiceId =  ( $tool_args | get appServiceId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/appservices/($appServiceId)/auditLogExports"  $query_params  $header_params  null
}

# Get Audit Log Export Job
# Retrieves details of a specific audit log export job for a given App Service.
# 
#  In order to access this endpoint, the provided API key must have at least one of the following roles:
#  - Organization Owner
#  - Project Owner
#  - Project Manager
#  - Project Viewer
# 
#  To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_getappserviceauditlogexportbyid [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  appServiceId =  ( $tool_args | get appServiceId ) 
   let  auditLogExportId =  ( $tool_args | get auditLogExportId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/appservices/($appServiceId)/auditLogExports/($auditLogExportId)"  $query_params  $header_params  null
}

# Get Database Credentials
# Fetches the details of a given cluster's database credential information.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
#  - Organization Owner
#  - Project Owner
#  - Project Viewer
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_getdatabasecredential [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  userId =  ( $tool_args | get userId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/users/($userId)"  $query_params  $header_params  null
}

# Update Database Credentials
# Updates an existing database credential.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def put_putdatabasecredential [
 tool_args 
] {
  mut header_params = []
  if ( ( $tool_args | get -i If-Match ) != null ) {
    $header_params = $header_params | append  { If-Match : ( $tool_args | get If-Match ) } 
  }
  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  userId =  ( $tool_args | get userId ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "PUT" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/users/($userId)"  $query_params  $header_params  $body
}

# Delete Database Credentials
# Deletes an existing cluster's database credential.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def delete_deletedatabasecredential [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  userId =  ( $tool_args | get userId ) 
  curl_request  "DELETE" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/users/($userId)"  $query_params  $header_params  null
}

# Create Free Tier Bucket
# Creates a new free tier bucket.  This is a Couchbase bucket where only the name a memory quota is configurable.
# Other bucket properties use default values.  
# 
# The following features are not available for free tier buckets:
#   - bucket flush 
#   - migrate to another storage engine like magma
# 
# Note that you can only create a free tier bucket on a free tier cluster.
# 
# To learn more about bucket configuration, see [Buckets](https://docs.couchbase.com/server/current/learn/buckets-memory-and-storage/buckets.html).
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def post_createfreetierbucket [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "POST" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/buckets/freeTier"  $query_params  $header_params  $body
}

# List Free Tier Buckets
# Lists all buckets in the free tier cluster. While only name and memory quota are configurable for free tier buckets, the response will show
# additional read only bucket properties such as replicas, etc.
# 
# To learn more about bucket configuration, see [Buckets](https://docs.couchbase.com/server/current/learn/buckets-memory-and-storage/buckets.html).
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# - Project Viewer
# - Database Data Reader/Writer
# - Database Data Reader
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_listfreetierbuckets [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/buckets/freeTier"  $query_params  $header_params  null
}

# Create Bucket
# Creates a new bucket configuration under a cluster.
# 
# To learn more about bucket configuration, see [Buckets](https://docs.couchbase.com/server/current/learn/buckets-memory-and-storage/buckets.html).
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def post_postbucket [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "POST" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/buckets"  $query_params  $header_params  $body
}

# List Buckets
# Lists all the buckets under the cluster.
# 
# To learn more about bucket configuration, see [Buckets](https://docs.couchbase.com/server/current/learn/buckets-memory-and-storage/buckets.html).
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# - Project Viewer
# - Database Data Reader/Writer
# - Database Data Reader
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_listbuckets [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/buckets"  $query_params  $header_params  null
}

# Get Free Tier Bucket
# Get bucket.  While only name and memory quota are configurable for free tier buckets, the response will show
# additional read only bucket properties such as replicas, etc.
# 
# To learn more about bucket configuration, see [Buckets](https://docs.couchbase.com/server/current/learn/buckets-memory-and-storage/buckets.html).
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# - Project Viewer
# - Database Data Reader/Writer
# - Database Data Reader
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_getfreetierbucketbyid [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  bucketId =  ( $tool_args | get bucketId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/buckets/freeTier/($bucketId)"  $query_params  $header_params  null
}

# Update Free Tier Bucket
# Updates an existing free tier bucket.  Only bucket memory quota is configurable.  Once created bucket name cannot be changed.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def put_updatefreetierbucket [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  bucketId =  ( $tool_args | get bucketId ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "PUT" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/buckets/freeTier/($bucketId)"  $query_params  $header_params  $body
}

# Delete Free Tier Bucket
# Deletes an existing free tier bucket.
# 
# To learn more about bucket configuration, see [Buckets](https://docs.couchbase.com/server/current/learn/buckets-memory-and-storage/buckets.html).
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def delete_deletefreetierbucketbyid [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  bucketId =  ( $tool_args | get bucketId ) 
  curl_request  "DELETE" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/buckets/freeTier/($bucketId)"  $query_params  $header_params  null
}

# Get Bucket
# Fetches the configuration of the given bucket.
# 
# To learn more about bucket configuration, see [Buckets](https://docs.couchbase.com/server/current/learn/buckets-memory-and-storage/buckets.html).
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# - Project Viewer
# - Database Data Reader/Writer
# - Database Data Reader
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_getbucketbyid [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  bucketId =  ( $tool_args | get bucketId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/buckets/($bucketId)"  $query_params  $header_params  null
}

# Update Bucket
# Updates an existing bucket.
# 
# To learn more about bucket configuration, see [Buckets](https://docs.couchbase.com/server/current/learn/buckets-memory-and-storage/buckets.html).
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def put_putbucket [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  bucketId =  ( $tool_args | get bucketId ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "PUT" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/buckets/($bucketId)"  $query_params  $header_params  $body
}

# Delete Bucket
# Deletes an existing bucket.
# 
# To learn more about bucket configuration, see [Buckets](https://docs.couchbase.com/server/current/learn/buckets-memory-and-storage/buckets.html).
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def delete_deletebucketbyid [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  bucketId =  ( $tool_args | get bucketId ) 
  curl_request  "DELETE" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/buckets/($bucketId)"  $query_params  $header_params  null
}

# Flush Bucket Data
# Flushing of the bucket occurs, causing all items in the bucket to be deleted by the system at the earliest opportunity.
# This operation can only be performed if the bucket has been configured with flushEnabled to true. If it is disabled, 
# it will throw an error.
# 
# It is recommended not to run with the flushEnabled configuration set to true in production; 
# due to the danger of all a bucket's data being inadvertently lost. 
# 
# To learn more about bucket configuration, see [Buckets](https://docs.couchbase.com/server/current/learn/buckets-memory-and-storage/buckets.html).
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def put_flushbucket [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  bucketId =  ( $tool_args | get bucketId ) 
  curl_request  "PUT" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/buckets/($bucketId)/flush"  $query_params  $header_params  null
}

# Migrate Buckets
# Updates the storage backend of an existing bucket from Couchstore to Magma.
# 
# The following should be noted while doing this operation -
# 
# 1. The outcome of this migration is that all data service nodes in the cluster will be replaced.
# - During the migration all buckets will remain operational and still be able to perform read and writes. Hence applications will not incur any downtime during this migration and can continue to read/write to the cluster.
# - The re-balances that occur from the node replacements will result in the bucket(s) being migrated to Magma.
# - The status of the cluster can be monitored via the [GET cluster API](https://docs.couchbase.com/cloud/management-api-reference/index.html#tag/clusters/operation/getCluster). The cluster will transition to healthy state after migration is completed for all listed buckets.
# 
# 2. This operation is only allowed for clusters with server version >= 7.6.0. The storage backend cannot be updated for the cluster with server versions lower than this. All the nodes must be upgraded to 7.6.0 before the bucket migration can be performed.
# 
# 3. Before migrating from Couchstore to Magma, the bucket memory allocation should be upgraded to at least the minimum amount required for a Magma bucket that is 1024 MiB.
# 
# 4. Cluster must be in a healthy state to perform this operation.
# 
# To learn more about bucket configuration, see [Buckets](https://docs.couchbase.com/server/current/learn/buckets-memory-and-storage/buckets.html).
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def put_putbucketstoragebackend [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "PUT" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/bucketStorageMigration"  $query_params  $header_params  $body
}

# Get Private Endpoint Service Status
# Private endpoint service allows you to access your Capella cluster from your private network, using private endpoints.
# 
# This endpoint determines if the endpoint service is enabled or disabled on your cluster.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
#   - Organization Owner
#   - Project Owner
#   - Project Manager
#   - Project Viewer
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_getprivateendpointservicestatus [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/privateEndpointService"  $query_params  $header_params  null
}

# Enable Private Endpoint Service
# Enable private endpoint service on your cluster.
# 
# Supporting infrastructure is deployed and it may take a few minutes for private endpoints to be available.
# After it's enabled, you can create private endpoint in your network.  You can do this using the cloud provider's CLI.  For an example, use
# the POST privateEndpointService/endpointCommand endpoint to get the command.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Manager
# - Project Owner
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def post_enableprivateendpointservice [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
  curl_request  "POST" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/privateEndpointService"  $query_params  $header_params  null
}

# Disable Private Endpoint Service
# Disable private endpoint service on your cluster.
# 
# Supporting infrastructure is removed and it may take a few minutes before private endpoints is disabled.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def delete_disableprivateendpointservice [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
  curl_request  "DELETE" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/privateEndpointService"  $query_params  $header_params  null
}

# List Private Endpoints
# Returns a list of private endpoints associated with the endpoint service for your Capella cluster, along
# with the endpoint state.  Each private endpoint connects a private network to the Capella cluster.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
#   - Organization Owner
#   - Project Owner
#   - Project Manager
#   - Project Creator
#   - Project Viewer
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_listprivateendpoints [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/privateEndpointService/endpoints"  $query_params  $header_params  null
}

# Get Private Endpoint CLI Command required to setup private endpoint for specific CSP
# Retrieve the command or script to be executed in order to create the private endpoint which will provides a private connection between the specified VPC and the specified Capella private endpoint service.  An example for AWS:
# 
# ```
# aws ec2 create-vpc-endpoint \
#   --vpc-id vpc-1234 \
#   --region us-east-1 \
#   --service-name com.amazonaws.vpce.us-east-1.vpce-svc-1234 \
#   --vpc-endpoint-type Interface \
#   --subnet-ids subnet-1234
# ```
# 
# An example for Azure:
# 
# ```
# az network private-endpoint create \
#   --connection-name connection-1 \
#   --name private-endpoint \
#   --private-connection-resource-id svc-1 \
#   --resource-group test-rg \
#   --subnet subnet-1 \
#   --group-id sites \
#   --vnet-name vnet-1
# ```
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
#   - Organization Owner
#   - Project Owner
#   - Project Manager
#   - Project Viewer
# 
#   To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def post_getprivateendpointcommand [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "POST" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/privateEndpointService/endpointCommand"  $query_params  $header_params  $body
}

# Accept Private Endpoint Request
# Accept a new private endpoint connection request so that it is associated with the endpoint service.  This means the private endpoint is available for use.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
#   - Organization Owner
#   - Project Owner
#   - Project Manager
# 
#   To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def post_acceptprivateendpoint [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  endpointId =  ( $tool_args | get endpointId ) 
  curl_request  "POST" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/privateEndpointService/endpoints/($endpointId)/associate"  $query_params  $header_params  null
}

# Reject or disassociate Private Endpoint
# Removes the private endpoint associated with the endpoint service.  This means the private endpoint is no
# longer able to connect to the private endpoint service.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def post_deleteprivateendpoint [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  endpointId =  ( $tool_args | get endpointId ) 
  curl_request  "POST" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/privateEndpointService/endpoints/($endpointId)/unassociate"  $query_params  $header_params  null
}

# Get Organization
# Fetches the details of an organization by ID.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Creator
# - Organization Member
# 
# To learn more, see [Organization Roles](https://docs.couchbase.com/cloud/organizations/organization-user-roles.html).
# 
def get_getorganizationbyid [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)"  $query_params  $header_params  null
}

# Update Organization Configuration
# Updates an existing organization configuration. Use this endpoint to add, update, and delete network subdomains.
# 
# Subdomains:
# - Can have a maximum of 30 alphanumeric characters.
# - Must be a unique string and not already in use in another tenant or organization. Empty strings are allowed.
# - Only affect new clusters. You cannot update existing clusters to include a new subdomain.
# - Currently only supported for AWS clusters.
# 
# In order to access this endpoint, the provided API key must have the following role:
# - Organization Owner
# 
# Subdomains are not automatically available. You must contact Couchbase support to enable this feature.
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def put_putorganizationconfiguration [
 tool_args 
] {
  mut header_params = []
  if ( ( $tool_args | get -i If-Match ) != null ) {
    $header_params = $header_params | append  { If-Match : ( $tool_args | get If-Match ) } 
  }
  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "PUT" $"/v4/organizations/($organizationId)/configuration"  $query_params  $header_params  $body
}

# List Organizations
# Returns a list of all organizations the user has access to.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Creator
# - Organization Member
# 
# To learn more, see [Organization Roles](https://docs.couchbase.com/cloud/organizations/organization-user-roles.html).
# 
def get_listorganizations [
 tool_args 
] {
  mut header_params = []

  mut query_params = []


  curl_request  "GET" $"/v4/organizations"  $query_params  $header_params  null
}

# Get Certificate
# In order to access this endpoint, the provided API key must have at least one of the following roles:
#   - Organization Owner
#   - Project Owner
#   - Project Manager
#   - Project Viewer
#   - Database Data Reader/Writer
#   - Database Data Reader
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_getcertificate [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/certificates"  $query_params  $header_params  null
}

# Load Sample Data
# Loads predefined sample data into a cluster by selecting from three available options:
# 
# - travel-sample 
# - gamesim-sample
# - beer-sample 
# 
# Upon a successful request, a new bucket is created within the cluster, and populated with the chosen sample data.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def post_postsamplebucket [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "POST" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/sampleBuckets"  $query_params  $header_params  $body
}

# List Sample Data Import Buckets
# Lists all the sample buckets under the organization.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# - Project Viewer
# - Database Data Reader/Writer
# - Database Data Reader
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_listsamplebuckets [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/sampleBuckets"  $query_params  $header_params  null
}

# Get Sample Import Bucket
# Fetches the configuration of the given bucket.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# - Project Viewer
# - Database Data Reader/Writer
# - Database Data Reader
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_getsamplebucketbyid [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  bucketId =  ( $tool_args | get bucketId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/sampleBuckets/($bucketId)"  $query_params  $header_params  null
}

# Delete Sample Import Bucket
# Deletes an existing bucket which was loaded with sample data.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def delete_deletesampledatabybucketid [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  bucketId =  ( $tool_args | get bucketId ) 
  curl_request  "DELETE" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/sampleBuckets/($bucketId)"  $query_params  $header_params  null
}

# Create Backup
# Creates an on-demand backup for a bucket.
# 
# To learn more about backup and restore, see [Backup and Restore Data](https://docs.couchbase.com/cloud/clusters/backup-restore.html).
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def post_postbackup [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  bucketId =  ( $tool_args | get bucketId ) 
  curl_request  "POST" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/buckets/($bucketId)/backups"  $query_params  $header_params  null
}

# List Cluster Backups
# Lists the latest backup for all buckets in a cluster.
# 
# Note: This endpoint doesn’t return queued backups and only returns ones that are actively being processed or are completed/failed.
# 
# To learn more about backup and restore, see [Backup and Restore Data](https://docs.couchbase.com/cloud/clusters/backup-restore.html).
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_listclusterbackups [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/backups"  $query_params  $header_params  null
}

# Get Backup
# Fetches the details of an existing backup.
# 
# To learn more about backup and restore, see [Backup and Restore Data](https://docs.couchbase.com/cloud/clusters/backup-restore.html).
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_getbackupbyid [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  backupId =  ( $tool_args | get backupId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/backups/($backupId)"  $query_params  $header_params  null
}

# Delete Backup Cycle
# Deletes the backup records that belong to the same cycle from the DB by using the backup ID.
# 
# To learn more about backup and restore, see [Backup and Restore Data](https://docs.couchbase.com/cloud/clusters/backup-restore.html).
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def delete_deletebackupcyclebyid [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  backupId =  ( $tool_args | get backupId ) 
  curl_request  "DELETE" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/backups/($backupId)"  $query_params  $header_params  null
}

# Create Cloud Snapshot Backup
# Creates a cloud snapshot backup for a cluster.
# 
# To learn more about backup and restore, see [Backup and Restore Data](https://docs.couchbase.com/cloud/clusters/cloud-snapshots.html).
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def post_createcloudsnapshotbackup [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "POST" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/cloudsnapshotbackups"  $query_params  $header_params  $body
}

# List Cloud Snapshot Backups
# List the backups belonging to a cluster.
# 
# Note: This endpoint doesn’t return queued backups and only returns ones that are actively being processed or are completed/failed.
# 
# To learn more about backup and restore, see [Backup and Restore Data](https://docs.couchbase.com/cloud/clusters/cloud-snapshots.html).
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_listcloudsnapshotbackups [
 tool_args 
] {
  mut header_params = []

  mut query_params = []
  if ( ( $tool_args | get -i page ) != null ) {
    $query_params = $query_params | append  { page : ( $tool_args | get page ) } 
  }
  if ( ( $tool_args | get -i perPage ) != null ) {
    $query_params = $query_params | append  { perPage : ( $tool_args | get perPage ) } 
  }
  if ( ( $tool_args | get -i sortBy ) != null ) {
    $query_params = $query_params | append  { sortBy : ( $tool_args | get sortBy ) } 
  }
  if ( ( $tool_args | get -i sortDirection ) != null ) {
    $query_params = $query_params | append  { sortDirection : ( $tool_args | get sortDirection ) } 
  }
  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/cloudsnapshotbackups"  $query_params  $header_params  null
}

# List Cloud Snapshot Restores
# Lists the restores that have taken place for a given cluster.
# 
# To learn more about backup and restore, see [Backup and Restore Data](https://docs.couchbase.com/cloud/clusters/cloud-snapshots.html).
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_listcloudsnapshotrestores [
 tool_args 
] {
  mut header_params = []

  mut query_params = []
  if ( ( $tool_args | get -i page ) != null ) {
    $query_params = $query_params | append  { page : ( $tool_args | get page ) } 
  }
  if ( ( $tool_args | get -i perPage ) != null ) {
    $query_params = $query_params | append  { perPage : ( $tool_args | get perPage ) } 
  }
  if ( ( $tool_args | get -i sortBy ) != null ) {
    $query_params = $query_params | append  { sortBy : ( $tool_args | get sortBy ) } 
  }
  if ( ( $tool_args | get -i sortDirection ) != null ) {
    $query_params = $query_params | append  { sortDirection : ( $tool_args | get sortDirection ) } 
  }
  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/cloudsnapshotbackups/restores"  $query_params  $header_params  null
}

# Edit Backup Retention
# Edits the retention time for a backup.
# 
# To learn more about backup and restore, see [Backup and Restore Data](https://docs.couchbase.com/cloud/clusters/cloud-snapshots.html).
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def put_editcloudsnapshotbackupretention [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  backupId =  ( $tool_args | get backupId ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "PUT" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/cloudsnapshotbackups/($backupId)"  $query_params  $header_params  $body
}

# Delete Backup
# Deletes the backup.
# 
# To learn more about backup and restore, see [Backup and Restore Data](https://docs.couchbase.com/cloud/clusters/cloud-snapshots.html).
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def delete_deletecloudsnapshotbackup [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  backupId =  ( $tool_args | get backupId ) 
  curl_request  "DELETE" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/cloudsnapshotbackups/($backupId)"  $query_params  $header_params  null
}

# Restore Backup
# Creates a restore job for a backup immediately.
# 
# To learn more about backup and restore, see [Backup and Restore Data](https://docs.couchbase.com/cloud/clusters/cloud-snapshots.html).
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def post_restore [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  backupId =  ( $tool_args | get backupId ) 
  curl_request  "POST" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/cloudsnapshotbackups/($backupId)/restore"  $query_params  $header_params  null
}

# List Cloud Snapshot Backups at the Project Level
# Lists cloud snapshot backups associated with operational clusters within a specific project.
# 
# The "most recent" and "oldest" backup fields do not include backups that are in a queued state. Only backups that are actively being processed, successfully completed, or marked as failed are returned.
# 
# For detailed guidance on backup and restore functionality, please refer to [Backup and Restore Data](https://docs.couchbase.com/cloud/clusters/cloud-snapshots.html).
# 
# The provided API key must have at least one of the following roles.
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# For more information about roles and access, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_listprojectlevelcloudsnapshotbackups [
 tool_args 
] {
  mut header_params = []

  mut query_params = []
  if ( ( $tool_args | get -i page ) != null ) {
    $query_params = $query_params | append  { page : ( $tool_args | get page ) } 
  }
  if ( ( $tool_args | get -i perPage ) != null ) {
    $query_params = $query_params | append  { perPage : ( $tool_args | get perPage ) } 
  }
  if ( ( $tool_args | get -i sortBy ) != null ) {
    $query_params = $query_params | append  { sortBy : ( $tool_args | get sortBy ) } 
  }
  if ( ( $tool_args | get -i sortDirection ) != null ) {
    $query_params = $query_params | append  { sortDirection : ( $tool_args | get sortDirection ) } 
  }
  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/cloudsnapshotbackups"  $query_params  $header_params  null
}

# Clone Cluster Backup
# Clones the cluster backup into a new cluster.
# 
# To learn more about backup and restore, see [Backup and Restore Data](https://docs.couchbase.com/cloud/clusters/cloud-snapshots.html).
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def post_clone [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  backupId =  ( $tool_args | get backupId ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "POST" $"/v4/organizations/($organizationId)/projects/($projectId)/cloudsnapshotbackups/($backupId)/clone"  $query_params  $header_params  $body
}

# Upsert Backup Schedule
# Creates or updates a cloud snapshot backup schedule for a cluster.
# 
# To learn more about backup and restore, see [Backup and Restore Data](https://docs.couchbase.com/cloud/clusters/cloud-snapshots.html).
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def put_upsertcloudsnapshotbackupschedule [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "PUT" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/cloudsnapshotbackupschedule"  $query_params  $header_params  $body
}

# Get Backup Schedule
# Retrieves the cloud snapshot backup schedule for a cluster.
# 
# To learn more about backup and restore, see [Backup and Restore Data](https://docs.couchbase.com/cloud/clusters/cloud-snapshots.html).
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_getcloudsnapshotbackupschedule [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/cloudsnapshotbackupschedule"  $query_params  $header_params  null
}

# Delete Backup Schedule
# Deletes the backup schedule for a cluster.
# 
# To learn more about backup and restore, see [Backup and Restore Data](https://docs.couchbase.com/cloud/clusters/cloud-snapshots.html).
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def delete_deletecloudsnapshotbackupschedule [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
  curl_request  "DELETE" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/cloudsnapshotbackupschedule"  $query_params  $header_params  null
}

# Create Backup Schedule
# Creates a scheduled backup for a bucket.
# 
# To learn more about backup and restore, see [Backup and Restore Data](https://docs.couchbase.com/cloud/clusters/backup-restore.html).
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def post_postbackupschedule [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  bucketId =  ( $tool_args | get bucketId ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "POST" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/buckets/($bucketId)/backup/schedules"  $query_params  $header_params  $body
}

# Get Backup Schedule
# Fetched the backup schedule for a bucket in a cluster.
# 
# To learn more about backup and restore, see [Backup and Restore Data](https://docs.couchbase.com/cloud/clusters/backup-restore.html).
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_getbackupschedule [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  bucketId =  ( $tool_args | get bucketId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/buckets/($bucketId)/backup/schedules"  $query_params  $header_params  null
}

# Update Backup Schedule
# Updates an existing backup schedule.
# 
# To learn more about backup and restore, see [Backup and Restore Data](https://docs.couchbase.com/cloud/clusters/backup-restore.html).
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def put_putbackupschedule [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  bucketId =  ( $tool_args | get bucketId ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "PUT" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/buckets/($bucketId)/backup/schedules"  $query_params  $header_params  $body
}

# Delete Backup Schedule
# Deletes an existing backup schedule
# 
# To learn more about backup and restore, see [Backup and Restore Data](https://docs.couchbase.com/cloud/clusters/backup-restore.html).
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def delete_deletebackupschedule [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  bucketId =  ( $tool_args | get bucketId ) 
  curl_request  "DELETE" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/buckets/($bucketId)/backup/schedules"  $query_params  $header_params  null
}

# List Cycles
# Lists the cycles for a bucket in a cluster.
# 
# To learn more about backup and restore, see [Backup and Restore Data](https://docs.couchbase.com/cloud/clusters/backup-restore.html).
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_listcycles [
 tool_args 
] {
  mut header_params = []

  mut query_params = []
  if ( ( $tool_args | get -i startDate ) != null ) {
    $query_params = $query_params | append  { startDate : ( $tool_args | get startDate ) } 
  }
  if ( ( $tool_args | get -i endDate ) != null ) {
    $query_params = $query_params | append  { endDate : ( $tool_args | get endDate ) } 
  }
  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  bucketId =  ( $tool_args | get bucketId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/buckets/($bucketId)/backup/cycles"  $query_params  $header_params  null
}

# List Backups
# Lists the backups for a cycle in a bucket.
# 
# To learn more about backup and restore, see [Backup and Restore Data](https://docs.couchbase.com/cloud/clusters/backup-restore.html).
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_listbackups [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  bucketId =  ( $tool_args | get bucketId ) 
   let  cycleId =  ( $tool_args | get cycleId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/buckets/($bucketId)/backup/cycles/($cycleId)"  $query_params  $header_params  null
}

# Restore Backup
# Creates an on-demand restore job for a backup immediately.
# 
# To learn more about backup and restore, see [Backup and Restore Data](https://docs.couchbase.com/cloud/clusters/backup-restore.html).
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def post_postrestore [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  backupId =  ( $tool_args | get backupId ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "POST" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/backups/($backupId)/restore"  $query_params  $header_params  $body
}

# Create Scope
# Creates a new scope in a bucket.
# 
# To learn more about scopes and collections, see [Buckets, Scopes, and Collections](https://docs.couchbase.com/cloud/clusters/data-service/about-buckets-scopes-collections.html).
# 
#  In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def post_postscope [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  bucketId =  ( $tool_args | get bucketId ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "POST" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/buckets/($bucketId)/scopes"  $query_params  $header_params  $body
}

# List Scopes
# Lists all the scopes in the bucket.
# 
# To learn more about scopes and collections, see [Buckets, Scopes, and Collections](https://docs.couchbase.com/cloud/clusters/data-service/about-buckets-scopes-collections.html).
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# - Project Viewer
# - Database Data Reader/Writer
# - Database Data Reader
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_getscopes [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  bucketId =  ( $tool_args | get bucketId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/buckets/($bucketId)/scopes"  $query_params  $header_params  null
}

# Get Scope
# Fetches the details of the given scope.
# 
# To learn more about scopes and collections, see [Buckets, Scopes, and Collections](https://docs.couchbase.com/cloud/clusters/data-service/about-buckets-scopes-collections.html).
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# - Project Viewer
# - Database Data Reader/Writer
# - Database Data Reader
# 
#  To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_getscopebyname [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  bucketId =  ( $tool_args | get bucketId ) 
   let  scopeName =  ( $tool_args | get scopeName ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/buckets/($bucketId)/scopes/($scopeName)"  $query_params  $header_params  null
}

# Delete Scope
# Deletes an existing scope.
# 
# To learn more about scopes and collections, see [Buckets, Scopes, and Collections](https://docs.couchbase.com/cloud/clusters/data-service/about-buckets-scopes-collections.html).
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def delete_deletescopebyname [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  bucketId =  ( $tool_args | get bucketId ) 
   let  scopeName =  ( $tool_args | get scopeName ) 
  curl_request  "DELETE" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/buckets/($bucketId)/scopes/($scopeName)"  $query_params  $header_params  null
}

# Create Collection
# Creates a new collection in a scope.
# 
# To learn more about scopes and collections, see [Buckets, Scopes, and Collections](https://docs.couchbase.com/cloud/clusters/data-service/about-buckets-scopes-collections.html).
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def post_postcollection [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  bucketId =  ( $tool_args | get bucketId ) 
   let  scopeName =  ( $tool_args | get scopeName ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "POST" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/buckets/($bucketId)/scopes/($scopeName)/collections"  $query_params  $header_params  $body
}

# List Collections
# Lists all the collections in a scope.
# 
# To learn more about scopes and collections, see [Buckets, Scopes, and Collections](https://docs.couchbase.com/cloud/clusters/data-service/about-buckets-scopes-collections.html).
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# - Project Viewer
# - Database Data Reader/Writer
# - Database Data Reader
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_getcollections [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  bucketId =  ( $tool_args | get bucketId ) 
   let  scopeName =  ( $tool_args | get scopeName ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/buckets/($bucketId)/scopes/($scopeName)/collections"  $query_params  $header_params  null
}

# Get Collection
# Fetches the details of the given collection.
# 
# To learn more about scopes and collections, see [Buckets, Scopes, and Collections](https://docs.couchbase.com/cloud/clusters/data-service/about-buckets-scopes-collections.html).
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# - Project Viewer
# - Database Data Reader/Writer
# - Database Data Reader
# 
#  To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_getcollectionbyname [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  bucketId =  ( $tool_args | get bucketId ) 
   let  scopeName =  ( $tool_args | get scopeName ) 
   let  collectionName =  ( $tool_args | get collectionName ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/buckets/($bucketId)/scopes/($scopeName)/collections/($collectionName)"  $query_params  $header_params  null
}

# Update Collection
# Updates an existing collection.
# 
# This operation is only allowed for a cluster with server version >= 7.6.0. A collection cannot be updated for the server versions lower than this.
# 
# This allows to update the maxTTL of the given collection.
# 
# To learn more about scopes and collections, see [Buckets, Scopes, and Collections](https://docs.couchbase.com/cloud/clusters/data-service/about-buckets-scopes-collections.html).
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def put_putcollection [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  bucketId =  ( $tool_args | get bucketId ) 
   let  scopeName =  ( $tool_args | get scopeName ) 
   let  collectionName =  ( $tool_args | get collectionName ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "PUT" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/buckets/($bucketId)/scopes/($scopeName)/collections/($collectionName)"  $query_params  $header_params  $body
}

# Delete Collection
# Deletes an existing collection.
# 
# To learn more about scopes and collections, see [Buckets, Scopes, and Collections](https://docs.couchbase.com/cloud/clusters/data-service/about-buckets-scopes-collections.html).
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def delete_deletecollectionbyname [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  bucketId =  ( $tool_args | get bucketId ) 
   let  scopeName =  ( $tool_args | get scopeName ) 
   let  collectionName =  ( $tool_args | get collectionName ) 
  curl_request  "DELETE" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/buckets/($bucketId)/scopes/($scopeName)/collections/($collectionName)"  $query_params  $header_params  null
}

# Create Network Peering
# Creates a network peering record for Capella. Capella does not support peering of networks between different cloud providers. For example, you cannot peer GCP VPC that hosts Capella cluster with an AWS VPC hosting an application.
# 
# - Create configures a Couchbase Capella private networking with the cloud provider. Setting up a private network enables your application to interact with Couchbase Capella over a private connection by co-locating them through network peering.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def post_postnetworkpeering [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "POST" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/networkPeers"  $query_params  $header_params  $body
}

# List Network Peering Records
# Lists all the network peering records.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_listnetworkpeeringrecords [
 tool_args 
] {
  mut header_params = []

  mut query_params = []
  if ( ( $tool_args | get -i page ) != null ) {
    $query_params = $query_params | append  { page : ( $tool_args | get page ) } 
  }
  if ( ( $tool_args | get -i perPage ) != null ) {
    $query_params = $query_params | append  { perPage : ( $tool_args | get perPage ) } 
  }
  if ( ( $tool_args | get -i sortBy ) != null ) {
    $query_params = $query_params | append  { sortBy : ( $tool_args | get sortBy ) } 
  }
  if ( ( $tool_args | get -i sortDirection ) != null ) {
    $query_params = $query_params | append  { sortDirection : ( $tool_args | get sortDirection ) } 
  }
  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/networkPeers"  $query_params  $header_params  null
}

# Get Network Peering record
# Fetches the details of the network peering meta data based on the peerID provided.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
#  - Organization Owner
#  - Project Owner
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_getnetworkpeeringrecord [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  peerId =  ( $tool_args | get peerId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/networkPeers/($peerId)"  $query_params  $header_params  null
}

# Delete Network Peering
# Deletes the network peering relationship.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def delete_deletenetworkpeering [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  peerId =  ( $tool_args | get peerId ) 
  curl_request  "DELETE" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/networkPeers/($peerId)"  $query_params  $header_params  null
}

# Create Alert Integration
# Creates a new alert integration for a project.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def post_postalertintegration [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "POST" $"/v4/organizations/($organizationId)/projects/($projectId)/alertIntegrations"  $query_params  $header_params  $body
}

# List Alert Integrations
# Lists all the alert integrations under the project.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Organization Member
# - Project Owner
# - Project Manager
# - Project Viewer
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_listalertintegrations [
 tool_args 
] {
  mut header_params = []

  mut query_params = []
  if ( ( $tool_args | get -i page ) != null ) {
    $query_params = $query_params | append  { page : ( $tool_args | get page ) } 
  }
  if ( ( $tool_args | get -i perPage ) != null ) {
    $query_params = $query_params | append  { perPage : ( $tool_args | get perPage ) } 
  }
  if ( ( $tool_args | get -i sortBy ) != null ) {
    $query_params = $query_params | append  { sortBy : ( $tool_args | get sortBy ) } 
  }
  if ( ( $tool_args | get -i sortDirection ) != null ) {
    $query_params = $query_params | append  { sortDirection : ( $tool_args | get sortDirection ) } 
  }
  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/alertIntegrations"  $query_params  $header_params  null
}

# Get Alert Integration
# Fetches the details of the given alert integration.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Organization Member
# - Project Owner
# - Project Manager
# - Project Viewer
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_getalertintegrationbyid [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  alertIntegrationId =  ( $tool_args | get alertIntegrationId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/alertIntegrations/($alertIntegrationId)"  $query_params  $header_params  null
}

# Update Alert Integration
# Update the details of the given alert integration.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def put_putalertintegration [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  alertIntegrationId =  ( $tool_args | get alertIntegrationId ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "PUT" $"/v4/organizations/($organizationId)/projects/($projectId)/alertIntegrations/($alertIntegrationId)"  $query_params  $header_params  $body
}

# Delete Alert Integration
# Deletes an existing alert integration.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def delete_deletealertintegrationbyid [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  alertIntegrationId =  ( $tool_args | get alertIntegrationId ) 
  curl_request  "DELETE" $"/v4/organizations/($organizationId)/projects/($projectId)/alertIntegrations/($alertIntegrationId)"  $query_params  $header_params  null
}

# Test Alert Integration
# Tests a new alert integration for a project.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
# - Organization Owner
# - Project Owner
# - Project Manager
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def post_posttestalertintegration [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "POST" $"/v4/organizations/($organizationId)/projects/($projectId)/alertIntegrationTest"  $query_params  $header_params  $body
}

# List Events
# Lists all the events information under a organization.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
#  - Organization Owner
#  - Project Creator
#  - Project Owner
#  - Project Manager
#  - Project Viewer
#  - Database Data Reader
#  - Database Data Reader/Writer
# 
# The results are always limited by the role and scope of the caller's privileges.
# Currently, only the `tags` filter is multi-valued; all other filters are single-valued.
# 
# By default, `to` is set to the request time, and `from` is set to 24 hours before the
# request time. If 'to' is set and 'from' is not set, then 'from' is set to 24 hours
# before 'to'.
# 
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_listevents [
 tool_args 
] {
  mut header_params = []

  mut query_params = []
  if ( ( $tool_args | get -i page ) != null ) {
    $query_params = $query_params | append  { page : ( $tool_args | get page ) } 
  }
  if ( ( $tool_args | get -i perPage ) != null ) {
    $query_params = $query_params | append  { perPage : ( $tool_args | get perPage ) } 
  }
  if ( ( $tool_args | get -i sortBy ) != null ) {
    $query_params = $query_params | append  { sortBy : ( $tool_args | get sortBy ) } 
  }
  if ( ( $tool_args | get -i sortDirection ) != null ) {
    $query_params = $query_params | append  { sortDirection : ( $tool_args | get sortDirection ) } 
  }
  if ( ( $tool_args | get -i userIds ) != null ) {
    $query_params = $query_params | append  { userIds : ( $tool_args | get userIds ) } 
  }
  if ( ( $tool_args | get -i clusterIds ) != null ) {
    $query_params = $query_params | append  { clusterIds : ( $tool_args | get clusterIds ) } 
  }
  if ( ( $tool_args | get -i projectIds ) != null ) {
    $query_params = $query_params | append  { projectIds : ( $tool_args | get projectIds ) } 
  }
  if ( ( $tool_args | get -i severityLevels ) != null ) {
    $query_params = $query_params | append  { severityLevels : ( $tool_args | get severityLevels ) } 
  }
  if ( ( $tool_args | get -i tags ) != null ) {
    $query_params = $query_params | append  { tags : ( $tool_args | get tags ) } 
  }
  if ( ( $tool_args | get -i from ) != null ) {
    $query_params = $query_params | append  { from : ( $tool_args | get from ) } 
  }
  if ( ( $tool_args | get -i to ) != null ) {
    $query_params = $query_params | append  { to : ( $tool_args | get to ) } 
  }
  let  organizationId =  ( $tool_args | get organizationId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/events"  $query_params  $header_params  null
}

# Get Event
# Fetches the details of an event by ID.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
#  - Organization Owner
#  - Project Creator
#  - Project Owner
#  - Project Manager
#  - Project Viewer
#  - Database Data Reader
#  - Database Data Reader/Writer
# 
# The results are always limited by the role and scope of the caller's privileges.
# 
# To learn more, see [Organization Roles](https://docs.couchbase.com/cloud/organizations/organization-user-roles.html).
# 
def get_geteventbyid [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  eventId =  ( $tool_args | get eventId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/events/($eventId)"  $query_params  $header_params  null
}

# List Events
# Lists all the events information under a project.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
#  - Organization Owner
#  - Project Owner
#  - Project Manager
#  - Project Viewer
#  - Database Data Reader
#  - Database Data Reader/Writer
# 
# The results are always limited by the role and scope of the caller's privileges.
# Currently, only the `tags` filter is multi-valued; all other filters are single-valued.
# 
# By default, `to` is set to the request time, and `from` is set to 24 hours before the
# request time. If 'to' is set and 'from' is not set, then 'from' is set to 24 hours
# before 'to'.
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_listprojectevents [
 tool_args 
] {
  mut header_params = []

  mut query_params = []
  if ( ( $tool_args | get -i page ) != null ) {
    $query_params = $query_params | append  { page : ( $tool_args | get page ) } 
  }
  if ( ( $tool_args | get -i perPage ) != null ) {
    $query_params = $query_params | append  { perPage : ( $tool_args | get perPage ) } 
  }
  if ( ( $tool_args | get -i sortBy ) != null ) {
    $query_params = $query_params | append  { sortBy : ( $tool_args | get sortBy ) } 
  }
  if ( ( $tool_args | get -i sortDirection ) != null ) {
    $query_params = $query_params | append  { sortDirection : ( $tool_args | get sortDirection ) } 
  }
  if ( ( $tool_args | get -i userIds ) != null ) {
    $query_params = $query_params | append  { userIds : ( $tool_args | get userIds ) } 
  }
  if ( ( $tool_args | get -i clusterIds ) != null ) {
    $query_params = $query_params | append  { clusterIds : ( $tool_args | get clusterIds ) } 
  }
  if ( ( $tool_args | get -i severityLevels ) != null ) {
    $query_params = $query_params | append  { severityLevels : ( $tool_args | get severityLevels ) } 
  }
  if ( ( $tool_args | get -i tags ) != null ) {
    $query_params = $query_params | append  { tags : ( $tool_args | get tags ) } 
  }
  if ( ( $tool_args | get -i from ) != null ) {
    $query_params = $query_params | append  { from : ( $tool_args | get from ) } 
  }
  if ( ( $tool_args | get -i to ) != null ) {
    $query_params = $query_params | append  { to : ( $tool_args | get to ) } 
  }
  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/events"  $query_params  $header_params  null
}

# Get Project Event
# Fetches the details of an event by ID within a project.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
#  - Organization Owner
#  - Project Owner
#  - Project Manager
#  - Project Viewer
#  - Database Data Reader
#  - Database Data Reader/Writer
# 
# The results are always limited by the role and scope of the caller's privileges.
# 
# To learn more, see [Organization Roles](https://docs.couchbase.com/cloud/organizations/organization-user-roles.html).
# 
def get_getprojecteventbyid [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  eventId =  ( $tool_args | get eventId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/events/($eventId)"  $query_params  $header_params  null
}

# Get Azure VNET Peering CLI Command
# Retrieves the role assignment command or script to be executed in the Azure CLI to assign a new network contributor role. It scopes only to the specified subscription and the virtual network within that subscription.
# 
# - Before using this API, please make sure that the *Admin consent granting* process has been completed through the Capella UI.
# - This process to grant consent to the VNET peering service principal in the external Azure tenant needs to be done only once for the organization i.e. the first time when the VNET peering is created.
# - Consenting to this permission request creates a service principal that grants Capella access to the Azure tenant to perform VNET peering.
# - To complete the admin consent granting process, the Organization owner should follow the steps below -
#     1. Login to the Capella UI.
#     2. Deploy an Azure Cluster or open an existing one you want to peer with your application.
#     3. Click the Settings tab, in the navigation pane click VNET Peering.
#     4. Click Setup VNET Peering.
#     5. Confirm that you have a user with the Global Administrator Role.
#     6. Add the Azure configuration details to allow peering access.
#     7. Click Allow Peering Access - A new browser tab opens. Sign in to Azure if you have not already.
#     8. In Azure, accept Capella’s permissions request - The Azure permissions request page is open in the new browser tab and consent to the new permissions request.
#       For more information refer [docs]- https://docs.couchbase.com/cloud/clouds/vpc-peering/peer-azure.html
# - On accepting the new permission, you automatically return to the Capella VNET peering page. The Capella VNET peering page shows a notice indicating that peering access is successful.
# 
# - The Organization Owner should set this up once, then for network peering, use the public API -
#     1. Use this `Get Azure VNET Peering CLI Command` API to fetch the command.
#     2. Run the role assignment command in the Azure CLI.
#     3. Use the `Create VPC Peering` API to create the network peering.
# 
# - In order to access this endpoint, the provided API key must have at least one of the following roles:
#   - Organization Owner
#   - Project Owner
# 
def post_getazurevnetpeeringcommand [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "POST" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/networkPeers/networkPeerCommand"  $query_params  $header_params  $body
}

# Manage Query Indexes
# CREATE/DROP/ALTER/BUILD primary and secondary indexes.
# 
# To learn more about indexes please refer to the [documentation](https://docs.couchbase.com/server/current/learn/services-and-indexes/indexes/indexing-and-query-perf.html).
# 
# It is recommended to use deferred index builds, especially for larger indexes. 
# When creating indexes in bulk, we do not recommend sending requests to create all of them at once. 
# Instead, we strongly recommend creating indexes in batches of 100 or less.
# 
# To access this endpoint the API key must have at least one of the following roles:
#   - Organization Owner
#   - Project Owner
#   - Database Data Reader/Writer
# 
# To learn more, see [Organization Roles](https://docs.couchbase.com/cloud/organizations/organization-user-roles.html).
# 
def post_managequeryindexes [
 tool_args 
] {
  mut header_params = []

  mut query_params = []

  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
  $header_params = $header_params | append  { "Content-Type" :  "application/json"} 
  let $body = ( $tool_args | get body )
  curl_request  "POST" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/queryService/indexes"  $query_params  $header_params  $body
}

# Get List Of Index Definitions
# Get index definitions in a keyspace.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
#   - Organization Owner
#   - Project Owner
#   - Database Data Reader/Writer
#   - Database Data Reader
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_listindexdefinitions [
 tool_args 
] {
  mut header_params = []

  mut query_params = []
  if ( ( $tool_args | get -i scope ) != null ) {
    $query_params = $query_params | append  { scope : ( $tool_args | get scope ) } 
  }
  if ( ( $tool_args | get -i collection ) != null ) {
    $query_params = $query_params | append  { collection : ( $tool_args | get collection ) } 
  }
  if ( ( $tool_args | get -i bucket ) != null ) {
    $query_params = $query_params | append  { bucket : ( $tool_args | get bucket ) } 
  }
  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/queryService/indexes"  $query_params  $header_params  null
}

# Get Index Properties
# Get the index properties of a specified index in a keyspace.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
#   - Organization Owner
#   - Project Owner
#   - Database Data Reader/Writer
#   - Database Data Reader
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_indexdefinition [
 tool_args 
] {
  mut header_params = []

  mut query_params = []
  if ( ( $tool_args | get -i scope ) != null ) {
    $query_params = $query_params | append  { scope : ( $tool_args | get scope ) } 
  }
  if ( ( $tool_args | get -i collection ) != null ) {
    $query_params = $query_params | append  { collection : ( $tool_args | get collection ) } 
  }
  if ( ( $tool_args | get -i bucket ) != null ) {
    $query_params = $query_params | append  { bucket : ( $tool_args | get bucket ) } 
  }
  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  indexName =  ( $tool_args | get indexName ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/queryService/indexes/($indexName)"  $query_params  $header_params  null
}

# Get Index Build Status
# Monitor the build status of an index.
# 
# In order to access this endpoint, the provided API key must have at least one of the following roles:
#   - Organization Owner
#   - Project Owner
#   - Database Data Reader/Writer
#   - Database Data Reader
# 
# To learn more, see [Organization, Project, and Database Access Overview](https://docs.couchbase.com/cloud/organizations/organization-projects-overview.html).
# 
def get_indexbuildstatus [
 tool_args 
] {
  mut header_params = []

  mut query_params = []
  if ( ( $tool_args | get -i scope ) != null ) {
    $query_params = $query_params | append  { scope : ( $tool_args | get scope ) } 
  }
  if ( ( $tool_args | get -i collection ) != null ) {
    $query_params = $query_params | append  { collection : ( $tool_args | get collection ) } 
  }
  if ( ( $tool_args | get -i bucket ) != null ) {
    $query_params = $query_params | append  { bucket : ( $tool_args | get bucket ) } 
  }
  let  organizationId =  ( $tool_args | get organizationId ) 
   let  projectId =  ( $tool_args | get projectId ) 
   let  clusterId =  ( $tool_args | get clusterId ) 
   let  indexName =  ( $tool_args | get indexName ) 
  curl_request  "GET" $"/v4/organizations/($organizationId)/projects/($projectId)/clusters/($clusterId)/queryService/indexBuildStatus/($indexName)"  $query_params  $header_params  null
}
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